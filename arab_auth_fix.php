<?php
/**
 * ARAB.PHP GA QO'SHISH KERAK BO'LGAN KOD
 * PHP 5.6+ bilan ishlaydi
 * 
 * Bu faylni arab.php dagi switch/route blokiga ko'chiring
 */

// ─── JWT sozlamalar ──────────────────────────────────────────────────────────
if (!defined('JWT_SECRET')) define('JWT_SECRET', 'arabtili_secret_key_2024');
if (!defined('JWT_EXPIRE'))  define('JWT_EXPIRE', 30 * 24 * 3600); // 30 kun

// ─── JWT funksiyalar ─────────────────────────────────────────────────────────

function arab_jwt_create($payload) {
    $header = rtrim(base64_encode(json_encode(array('alg'=>'HS256','typ'=>'JWT'))), '=');
    $pay    = rtrim(base64_encode(json_encode($payload)), '=');
    $sig    = rtrim(base64_encode(hash_hmac('sha256', $header.'.'.$pay, JWT_SECRET, true)), '=');
    return $header.'.'.$pay.'.'.$sig;
}

function arab_jwt_verify($token) {
    $parts = explode('.', $token);
    if (count($parts) !== 3) return null;
    $header = $parts[0]; $pay = $parts[1]; $sig = $parts[2];
    $expected = rtrim(base64_encode(hash_hmac('sha256', $header.'.'.$pay, JWT_SECRET, true)), '=');
    if (!hash_equals($expected, $sig)) return null;
    $payload = json_decode(base64_decode($pay.'=='), true);
    if (!$payload) return null;
    if (isset($payload['exp']) && $payload['exp'] < time()) return null;
    return $payload;
}

// ─── Google dan user ma'lumotlarini olish ────────────────────────────────────

function arab_get_google_user($id_token, $access_token) {
    
    // 1-usul: access_token bilan Google userinfo API (eng ishonchli)
    if (!empty($access_token) && strlen($access_token) > 10) {
        $ch = curl_init('https://www.googleapis.com/oauth2/v3/userinfo');
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, array('Authorization: Bearer '.$access_token));
        curl_setopt($ch, CURLOPT_TIMEOUT, 10);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false); // PHP 5.6 uchun
        $result = curl_exec($ch);
        $err    = curl_error($ch);
        curl_close($ch);
        
        if (!$err && $result) {
            $data = json_decode($result, true);
            if ($data && !isset($data['error']) && !empty($data['email'])) {
                return array(
                    'google_id' => isset($data['sub']) ? $data['sub'] : '',
                    'email'     => $data['email'],
                    'name'      => isset($data['name'])    ? $data['name']    : '',
                    'avatar'    => isset($data['picture']) ? $data['picture'] : '',
                );
            }
        }
    }
    
    // 2-usul: id_token bilan Google tokeninfo API
    if (!empty($id_token) && strlen($id_token) > 50) {
        $url = 'https://oauth2.googleapis.com/tokeninfo?id_token='.urlencode($id_token);
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 10);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false); // PHP 5.6 uchun
        $result = curl_exec($ch);
        $err    = curl_error($ch);
        curl_close($ch);
        
        if (!$err && $result) {
            $data = json_decode($result, true);
            if ($data && !isset($data['error']) && !empty($data['email'])) {
                return array(
                    'google_id' => isset($data['sub'])     ? $data['sub']     : '',
                    'email'     => $data['email'],
                    'name'      => isset($data['name'])    ? $data['name']    : '',
                    'avatar'    => isset($data['picture']) ? $data['picture'] : '',
                );
            }
        }
    }
    
    return null;
}

// ─── Users DB (JSON fayl, keyinchalik MySQL ga almashtirish mumkin) ──────────

function arab_load_users() {
    $f = __DIR__.'/arab_users.json';
    if (!file_exists($f)) return array();
    $data = json_decode(file_get_contents($f), true);
    return is_array($data) ? $data : array();
}

function arab_save_users($users) {
    file_put_contents(__DIR__.'/arab_users.json', json_encode($users, JSON_PRETTY_PRINT));
}

// ─── ROUTE: google_auth ───────────────────────────────────────────────────────
// POST /arab.php?route=google_auth
// Body: {
//   "token": "...",        ← Google ID token
//   "id_token": "...",     ← Google ID token (boshqa nom bilan)
//   "access_token": "...", ← Google access token
//   "email": "...",        ← fallback
//   "name": "...",         ← fallback
//   "avatar": "..."        ← fallback
// }

function route_google_auth_new() {
    header('Content-Type: application/json');
    
    $body = json_decode(file_get_contents('php://input'), true);
    if (!$body) {
        echo json_encode(array('error' => 'invalid request body'));
        exit;
    }
    
    $id_token     = isset($body['id_token'])     ? $body['id_token']     : (isset($body['token']) ? $body['token'] : '');
    $access_token = isset($body['access_token']) ? $body['access_token'] : '';
    $fb_email     = isset($body['email'])  ? trim($body['email'])  : '';
    $fb_name      = isset($body['name'])   ? trim($body['name'])   : '';
    $fb_avatar    = isset($body['avatar']) ? trim($body['avatar']) : '';
    
    // Google dan user ma'lumotlarini olish
    $guser = arab_get_google_user($id_token, $access_token);
    
    // Google API ishlamagan taqdirda — email fallback ishlatish
    // (FAQAT development uchun, production-da olib tashlang)
    if (!$guser && !empty($fb_email)) {
        $guser = array(
            'google_id' => md5($fb_email),
            'email'     => $fb_email,
            'name'      => $fb_name,
            'avatar'    => $fb_avatar,
        );
    }
    
    if (!$guser || empty($guser['email'])) {
        echo json_encode(array('error' => 'invalid token'));
        exit;
    }
    
    // Users DB-dan qidirish yoki yangi yaratish
    $users   = arab_load_users();
    $email   = $guser['email'];
    $user_id = null;
    
    foreach ($users as $uid => $u) {
        if (isset($u['email']) && $u['email'] === $email) {
            $user_id = $uid;
            break;
        }
    }
    
    if ($user_id === null) {
        $user_id = 'u'.time().rand(100,999);
        $users[$user_id] = array(
            'id'      => $user_id,
            'email'   => $email,
            'name'    => !empty($guser['name'])   ? $guser['name']   : $fb_name,
            'avatar'  => !empty($guser['avatar']) ? $guser['avatar'] : $fb_avatar,
            'gid'     => $guser['google_id'],
            'created' => time(),
        );
    } else {
        // Mavjud user-ni yangilash
        if (!empty($guser['name']))   $users[$user_id]['name']   = $guser['name'];
        if (!empty($guser['avatar'])) $users[$user_id]['avatar'] = $guser['avatar'];
    }
    
    arab_save_users($users);
    $user = $users[$user_id];
    
    // JWT yaratish (30 kun)
    $jwt = arab_jwt_create(array(
        'uid' => $user_id,
        'email' => $email,
        'iat' => time(),
        'exp' => time() + JWT_EXPIRE,
    ));
    
    echo json_encode(array(
        'access_token' => $jwt,
        'user_id'      => $user_id,
        'email'        => $user['email'],
        'name'         => $user['name'],
        'avatar'       => $user['avatar'],
    ));
    exit;
}

// ─── ROUTE: me ───────────────────────────────────────────────────────────────
// GET /arab.php?route=me
// Header: Authorization: Bearer JWT_TOKEN

function route_me_new() {
    header('Content-Type: application/json');
    
    $auth = '';
    if (isset($_SERVER['HTTP_AUTHORIZATION']))          $auth = $_SERVER['HTTP_AUTHORIZATION'];
    elseif (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) $auth = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
    
    if (empty($auth) || strpos($auth, 'Bearer ') !== 0) {
        http_response_code(401);
        echo json_encode(array('error' => 'token required'));
        exit;
    }
    
    $token   = substr($auth, 7);
    $payload = arab_jwt_verify($token);
    
    if (!$payload) {
        http_response_code(401);
        echo json_encode(array('error' => 'invalid or expired token'));
        exit;
    }
    
    $users   = arab_load_users();
    $user_id = isset($payload['uid']) ? $payload['uid'] : '';
    $user    = isset($users[$user_id]) ? $users[$user_id] : null;
    
    if (!$user) {
        http_response_code(404);
        echo json_encode(array('error' => 'user not found'));
        exit;
    }
    
    echo json_encode(array(
        'user_id' => $user['id'],
        'email'   => $user['email'],
        'name'    => $user['name'],
        'avatar'  => $user['avatar'],
    ));
    exit;
}

/*
 * ═══════════════════════════════════════════════════════════
 *  ARAB.PHP GA QO'SHISH TARTIBI:
 * ═══════════════════════════════════════════════════════════
 * 
 * 1. Yuqoridagi barcha funksiyalarni arab.php ga ko'chiring
 * 
 * 2. Route handling qismiga qo'shing:
 * 
 *    $route = isset($_GET['route']) ? $_GET['route'] : '';
 *    
 *    switch ($route) {
 *        // ... mavjud routelar ...
 *        
 *        case 'google_auth':
 *            route_google_auth_new();
 *            break;
 *        
 *        case 'me':
 *            route_me_new();
 *            break;
 *    }
 * 
 * 3. arab_users.json faylini serverda yozish uchun ruxsat bering:
 *    chmod 666 arab_users.json  (yoki PHP yoza oladigan joyga qo'ying)
 * 
 * ═══════════════════════════════════════════════════════════
 * 
 *  FLUTTER DAN KELAYOTGAN SO'ROV FORMAT:
 * 
 *  POST http://luxcontent.uz/arab.php?route=google_auth
 *  Content-Type: application/json
 *  Body: {
 *    "token":        "eyJhbGci....(~1000 belgi Google ID JWT)",
 *    "id_token":     "eyJhbGci....(xuddi shu)",
 *    "access_token": "ya29.......(Google OAuth access token)",
 *    "email":        "foydalanuvchi@gmail.com",
 *    "name":         "Foydalanuvchi Ismi",
 *    "avatar":       "https://lh3.googleusercontent.com/..."
 *  }
 * 
 *  KUTILGAN JAVOB:
 *  {
 *    "access_token": "arabtili.eyJ...(30 kunlik JWT)",
 *    "user_id":      "u123456",
 *    "email":        "foydalanuvchi@gmail.com",
 *    "name":         "Foydalanuvchi Ismi",
 *    "avatar":       "https://..."
 *  }
 * ═══════════════════════════════════════════════════════════
 */
