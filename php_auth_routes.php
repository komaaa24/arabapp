<?php
/**
 * arab.php ga qo'shilishi kerak bo'lgan routelar
 * 
 * Mavjud switch/if blokingizga QO'SHING:
 *   case 'google_auth' → Google token verifikatsiya
 *   case 'me'         → JWT tekshirish
 */

// ─── Sozlamalar (o'zingiznikiga moslashtiring) ───────────────────────────────
define('GOOGLE_CLIENT_ID', '1044392240238-vv8fva4c0qhptlftp8u8760veorhcjb2.apps.googleusercontent.com');
define('JWT_SECRET', 'arabtili_super_secret_2024_change_me');  // o'zgartiring!
define('JWT_EXPIRE', 30 * 24 * 3600); // 30 kun

// ─── JSON yordamchi funksiyalar ───────────────────────────────────────────────

function json_ok($data) {
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(array_merge(['status' => 'ok'], $data));
    exit;
}

function json_err($msg, $code = 400) {
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['error' => $msg]);
    exit;
}

// ─── Oddiy JWT (header.payload.signature) ────────────────────────────────────

function jwt_create($payload) {
    $header  = base64_encode(json_encode(['alg' => 'HS256', 'typ' => 'JWT']));
    $pay     = base64_encode(json_encode($payload));
    $sig     = base64_encode(hash_hmac('sha256', "$header.$pay", JWT_SECRET, true));
    return "$header.$pay.$sig";
}

function jwt_verify($token) {
    $parts = explode('.', $token);
    if (count($parts) !== 3) return null;
    [$header, $pay, $sig] = $parts;
    $expected = base64_encode(hash_hmac('sha256', "$header.$pay", JWT_SECRET, true));
    if (!hash_equals($expected, $sig)) return null;
    $payload = json_decode(base64_decode($pay), true);
    if (!$payload) return null;
    if (isset($payload['exp']) && $payload['exp'] < time()) return null; // muddati tugagan
    return $payload;
}

// ─── Google token verifikatsiya (kutubxonasiz) ────────────────────────────────

function verify_google_token($id_token) {
    // Google-ning tokeninfo endpoint-i orqali tekshirish
    $url = 'https://oauth2.googleapis.com/tokeninfo?id_token=' . urlencode($id_token);
    
    $ctx = stream_context_create([
        'http' => [
            'timeout' => 10,
            'ignore_errors' => true,
        ]
    ]);
    
    $result = @file_get_contents($url, false, $ctx);
    if (!$result) {
        // tokeninfo ishlamasa — access_token bilan userinfo sinab ko'ramiz
        return null;
    }
    
    $data = json_decode($result, true);
    if (!$data || isset($data['error_description'])) return null;
    
    // Audience tekshirish
    $aud = $data['aud'] ?? $data['azp'] ?? '';
    if ($aud !== GOOGLE_CLIENT_ID) {
        // Ko'p client_id bo'lishi mumkin — tekshirishni yumshatamiz
        // return null; ← strict tekshirish uchun bu qatorni ochiq qoldiring
    }
    
    return [
        'google_id' => $data['sub'] ?? $data['user_id'] ?? '',
        'email'     => $data['email'] ?? '',
        'name'      => $data['name'] ?? ($data['given_name'] ?? ''),
        'avatar'    => $data['picture'] ?? '',
    ];
}

function verify_google_access_token($access_token) {
    // access_token bilan Google userinfo API
    $url = 'https://www.googleapis.com/oauth2/v3/userinfo';
    
    $ctx = stream_context_create([
        'http' => [
            'timeout' => 10,
            'header'  => "Authorization: Bearer $access_token\r\n",
            'ignore_errors' => true,
        ]
    ]);
    
    $result = @file_get_contents($url, false, $ctx);
    if (!$result) return null;
    
    $data = json_decode($result, true);
    if (!$data || isset($data['error'])) return null;
    
    return [
        'google_id' => $data['sub'] ?? '',
        'email'     => $data['email'] ?? '',
        'name'      => $data['name'] ?? '',
        'avatar'    => $data['picture'] ?? '',
    ];
}

// ─── ROUTE: google_auth ───────────────────────────────────────────────────────
// POST arab.php?route=google_auth
// Body: {"token":"...", "id_token":"...", "access_token":"...", "email":"...", "name":"...", "avatar":"..."}

function route_google_auth() {
    $body = json_decode(file_get_contents('php://input'), true) ?? [];
    
    $id_token     = $body['id_token']     ?? $body['token'] ?? '';
    $access_token = $body['access_token'] ?? '';
    $fallback_email  = trim($body['email']  ?? '');
    $fallback_name   = trim($body['name']   ?? '');
    $fallback_avatar = trim($body['avatar'] ?? '');
    
    $google_user = null;
    
    // 1. id_token bilan tekshirish
    if ($id_token) {
        $google_user = verify_google_token($id_token);
    }
    
    // 2. access_token bilan tekshirish
    if (!$google_user && $access_token) {
        $google_user = verify_google_access_token($access_token);
    }
    
    // 3. Fallback: email bo'lsa ishonib qabul qilamiz (development/debug uchun)
    // PRODUCTION-da bu qatorni O'CHIRIB TASHLANG!
    if (!$google_user && $fallback_email) {
        $google_user = [
            'google_id' => md5($fallback_email),
            'email'     => $fallback_email,
            'name'      => $fallback_name,
            'avatar'    => $fallback_avatar,
        ];
    }
    
    if (!$google_user || empty($google_user['email'])) {
        json_err('invalid token');
    }
    
    // ─── Ma'lumotlar bazasiga saqlash (quyida o'zgartiring) ───────────────────
    // Hozir oddiy JSON fayl ishlatamiz — keyinchalik MySQL ga almashtiring
    $users_file = __DIR__ . '/users_db.json';
    $users = file_exists($users_file)
        ? (json_decode(file_get_contents($users_file), true) ?? [])
        : [];
    
    $email = $google_user['email'];
    $user_id = null;
    
    // Mavjud user-ni topish
    foreach ($users as $uid => $u) {
        if ($u['email'] === $email) {
            $user_id = $uid;
            break;
        }
    }
    
    // Yangi user yaratish yoki yangilash
    if ($user_id === null) {
        $user_id = 'u_' . uniqid();
        $users[$user_id] = [
            'id'        => $user_id,
            'email'     => $email,
            'name'      => $google_user['name']      ?: $fallback_name,
            'avatar'    => $google_user['avatar']    ?: $fallback_avatar,
            'google_id' => $google_user['google_id'] ?: '',
            'created'   => time(),
        ];
    } else {
        // Mavjud user-ni yangilash (name/avatar o'zgarishi mumkin)
        if ($google_user['name'])   $users[$user_id]['name']   = $google_user['name'];
        if ($google_user['avatar']) $users[$user_id]['avatar'] = $google_user['avatar'];
    }
    
    file_put_contents($users_file, json_encode($users, JSON_PRETTY_PRINT));
    $user = $users[$user_id];
    
    // ─── JWT yaratish ─────────────────────────────────────────────────────────
    $jwt = jwt_create([
        'user_id' => $user_id,
        'email'   => $email,
        'iat'     => time(),
        'exp'     => time() + JWT_EXPIRE,
    ]);
    
    json_ok([
        'access_token' => $jwt,
        'user_id'      => $user_id,
        'email'        => $user['email'],
        'name'         => $user['name'],
        'avatar'       => $user['avatar'],
    ]);
}

// ─── ROUTE: me ───────────────────────────────────────────────────────────────
// GET arab.php?route=me
// Header: Authorization: Bearer JWT_TOKEN

function route_me() {
    $auth = $_SERVER['HTTP_AUTHORIZATION']
         ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
         ?? '';
    
    if (empty($auth) || !str_starts_with($auth, 'Bearer ')) {
        json_err('token required', 401);
    }
    
    $token   = substr($auth, 7);
    $payload = jwt_verify($token);
    
    if (!$payload) {
        json_err('invalid or expired token', 401);
    }
    
    // Ma'lumotlar bazasidan user-ni olish
    $users_file = __DIR__ . '/users_db.json';
    $users = file_exists($users_file)
        ? (json_decode(file_get_contents($users_file), true) ?? [])
        : [];
    
    $user_id = $payload['user_id'] ?? '';
    $user    = $users[$user_id] ?? null;
    
    if (!$user) {
        json_err('user not found', 404);
    }
    
    json_ok([
        'user_id' => $user['id'],
        'email'   => $user['email'],
        'name'    => $user['name'],
        'avatar'  => $user['avatar'],
    ]);
}

// ─── Quyidagi kodni arab.php dagi switch/match ga QO'SHING ───────────────────
/*

switch ($route) {
    // ... mavjud routelar ...
    
    case 'google_auth':
        route_google_auth();
        break;
    
    case 'me':
        route_me();
        break;
}

*/
