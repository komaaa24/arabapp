<?php
/**
 * TUZATILGAN google_auth.php
 * Serverga yuklash: /var/www/html/api/routes/google_auth.php
 *
 * Xato: id_token bo'sh bo'lsa access_token tokeninfo ga uzatilardi → HTTP 400
 * To'g'ri:  id_token → tokeninfo
 *           access_token → userinfo (alohida endpoint)
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit; }

// ─── So'rov body ni o'qish (JSON yoki form) ──────────────────────────────────
$body = json_decode(file_get_contents('php://input'), true);
if (empty($body)) {
    // Form-urlencoded fallback
    $body = $_POST;
}

// ─── Tokenlarni ALOHIDA olish (aralashtirmaslik!) ────────────────────────────
$id_token     = isset($body['id_token'])     && !empty($body['id_token'])     ? trim($body['id_token'])     : null;
$access_token = isset($body['access_token']) && !empty($body['access_token']) ? trim($body['access_token']) : null;
$fb_email     = isset($body['email'])  ? trim($body['email'])  : '';
$fb_name      = isset($body['name'])   ? trim($body['name'])   : '';
$fb_avatar    = isset($body['avatar']) ? trim($body['avatar']) : '';

$google_user = null;

// ─── 1-usul: id_token → tokeninfo (faqat JWT eyJ... bilan) ──────────────────
if ($id_token && strlen($id_token) > 100) {
    $url    = 'https://oauth2.googleapis.com/tokeninfo?id_token=' . urlencode($id_token);
    $result = @file_get_contents($url, false, stream_context_create([
        'http' => ['timeout' => 10, 'ignore_errors' => true]
    ]));
    if ($result) {
        $data = json_decode($result, true);
        if ($data && empty($data['error']) && !empty($data['email'])) {
            $google_user = [
                'google_id' => $data['sub']     ?? '',
                'email'     => $data['email'],
                'name'      => $data['name']    ?? ($data['given_name'] ?? ''),
                'avatar'    => $data['picture'] ?? '',
            ];
        }
    }
}

// ─── 2-usul: access_token → userinfo (ya29... uchun TO'G'RI endpoint) ────────
if (!$google_user && $access_token) {
    $ctx    = stream_context_create([
        'http' => [
            'timeout'       => 10,
            'header'        => "Authorization: Bearer $access_token\r\n",
            'ignore_errors' => true,
        ]
    ]);
    $result = @file_get_contents('https://www.googleapis.com/oauth2/v3/userinfo', false, $ctx);
    if ($result) {
        $data = json_decode($result, true);
        if ($data && empty($data['error']) && !empty($data['email'])) {
            $google_user = [
                'google_id' => $data['sub']     ?? '',
                'email'     => $data['email'],
                'name'      => $data['name']    ?? '',
                'avatar'    => $data['picture'] ?? '',
            ];
        }
    }
}

// ─── 3-usul: email fallback (development uchun) ──────────────────────────────
// PRODUCTION-da bu blokni o'chirib tashlang!
if (!$google_user && !empty($fb_email)) {
    $google_user = [
        'google_id' => md5($fb_email),
        'email'     => $fb_email,
        'name'      => $fb_name,
        'avatar'    => $fb_avatar,
    ];
}

if (!$google_user || empty($google_user['email'])) {
    echo json_encode(['error' => 'invalid token']);
    exit;
}

// ─── User DB dan qidirish / yaratish ─────────────────────────────────────────
// Mavjud users fayli yoki DB bilan almashtiring
$users_file = __DIR__ . '/../arab_users.json';
if (!file_exists($users_file)) $users_file = __DIR__ . '/../../arab_users.json';
if (!file_exists($users_file)) $users_file = dirname(__FILE__) . '/arab_users.json';

$users   = file_exists($users_file)
    ? (json_decode(file_get_contents($users_file), true) ?? [])
    : [];

$email   = $google_user['email'];
$user_id = null;

foreach ($users as $uid => $u) {
    if (isset($u['email']) && $u['email'] === $email) {
        $user_id = $uid;
        break;
    }
}

if ($user_id === null) {
    $user_id           = 'u' . time() . rand(100, 999);
    $users[$user_id]   = [
        'id'      => $user_id,
        'email'   => $email,
        'name'    => !empty($google_user['name'])   ? $google_user['name']   : $fb_name,
        'avatar'  => !empty($google_user['avatar']) ? $google_user['avatar'] : $fb_avatar,
        'gid'     => $google_user['google_id'],
        'created' => date('Y-m-d H:i:s'),
    ];
} else {
    if (!empty($google_user['name']))   $users[$user_id]['name']   = $google_user['name'];
    if (!empty($google_user['avatar'])) $users[$user_id]['avatar'] = $google_user['avatar'];
}

@file_put_contents($users_file, json_encode($users, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
$user = $users[$user_id];

// ─── JWT yaratish ─────────────────────────────────────────────────────────────
// JWT_SECRET va jwt_create funksiyasi index.php dan o'qiladi
if (!function_exists('jwt_create')) {
    // Agar alohida ishlatilsa — inline
    $secret = defined('JWT_SECRET') ? JWT_SECRET : 'arabtili_secret_key_2024';
    $exp    = time() + 30 * 24 * 3600;
    $h = rtrim(base64_encode(json_encode(['alg'=>'HS256','typ'=>'JWT'])), '=');
    $p = rtrim(base64_encode(json_encode(['uid'=>$user_id,'email'=>$email,'iat'=>time(),'exp'=>$exp])), '=');
    $s = rtrim(base64_encode(hash_hmac('sha256', "$h.$p", $secret, true)), '=');
    $jwt = "$h.$p.$s";
} else {
    $jwt = jwt_create(['uid' => $user_id, 'email' => $email, 'iat' => time(), 'exp' => time() + 30 * 24 * 3600]);
}

echo json_encode([
    'status'       => 'ok',
    'access_token' => $jwt,
    'user_id'      => $user_id,
    'email'        => $user['email'],
    'name'         => $user['name']   ?? '',
    'avatar'       => $user['avatar'] ?? '',
]);
exit;
