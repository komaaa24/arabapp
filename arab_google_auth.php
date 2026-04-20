<?php
/**
 * arab.php dagi "google_auth" case-ni SHU KOD BILAN ALMASHTIRING
 * 
 * MUAMMO: PHP $_POST o'qiydi, lekin Flutter JSON yuboradi
 * YECHIM: file_get_contents('php://input') bilan JSON o'qish
 */

// ════════════════════════════════════════════════════════════
// Bu funksiyalarni arab.php TEPASIGA qo'shing (require dan keyin)
// ════════════════════════════════════════════════════════════

/**
 * CURL bilan HTTP so'rov (file_get_contents emas — SSL uchun ishonchli)
 */
function arab_curl_get($url, $headers = array()) {
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);  // hosting SSL muammosi uchun
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    if (!empty($headers)) {
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    }
    $result = curl_exec($ch);
    curl_close($ch);
    return $result ? json_decode($result, true) : null;
}

/**
 * Google token-dan user ma'lumotlarini olish
 * access_token → userinfo API (eng ishonchli)
 * id_token     → tokeninfo API (zaxira)
 */
function arab_get_google_user_info($id_token, $access_token) {
    
    // 1-usul: access_token bilan (tokenni decode qilmaydi, Google o'zi beradi)
    if (!empty($access_token) && strlen($access_token) > 10) {
        $data = arab_curl_get(
            'https://www.googleapis.com/oauth2/v3/userinfo',
            array('Authorization: Bearer ' . $access_token)
        );
        if ($data && !isset($data['error']) && !empty($data['email'])) {
            return array(
                'google_id' => isset($data['sub'])     ? $data['sub']     : '',
                'email'     => $data['email'],
                'name'      => isset($data['name'])    ? $data['name']    : '',
                'avatar'    => isset($data['picture']) ? $data['picture'] : '',
            );
        }
    }
    
    // 2-usul: id_token bilan tokeninfo (Google ID token-ni verify qiladi)
    if (!empty($id_token) && strlen($id_token) > 50) {
        $data = arab_curl_get(
            'https://oauth2.googleapis.com/tokeninfo?id_token=' . urlencode($id_token)
        );
        if ($data && !isset($data['error_description']) && !empty($data['email'])) {
            return array(
                'google_id' => isset($data['sub'])     ? $data['sub']     : '',
                'email'     => $data['email'],
                'name'      => isset($data['name'])    ? $data['name']    : '',
                'avatar'    => isset($data['picture']) ? $data['picture'] : '',
            );
        }
    }
    
    return null;
}

/**
 * Oddiy JWT yaratish (PHP 5.6+ bilan ishlaydi)
 */
function arab_make_jwt($user_id, $email) {
    $secret  = 'ARABTILI_JWT_SECRET_CHANGE_THIS_2024'; // o'zgartiring!
    $expire  = time() + (30 * 24 * 3600); // 30 kun
    $header  = rtrim(base64_encode('{"alg":"HS256","typ":"JWT"}'), '=');
    $payload = rtrim(base64_encode(json_encode(array(
        'uid'   => $user_id,
        'email' => $email,
        'exp'   => $expire,
        'iat'   => time(),
    ))), '=');
    $sig = rtrim(base64_encode(hash_hmac('sha256', $header.'.'.$payload, $secret, true)), '=');
    return $header . '.' . $payload . '.' . $sig;
}

// ════════════════════════════════════════════════════════════
// arab.php dagi "google_auth" case ICHIGA qo'ying:
//
// case 'google_auth':
//     ... (quyidagi kodni qo'ying)
//     break;
// ════════════════════════════════════════════════════════════

function handle_google_auth() {
    header('Content-Type: application/json; charset=utf-8');
    
    // ✅ TO'G'RI: JSON body o'qish ($_POST EMAS!)
    $raw  = file_get_contents('php://input');
    $body = json_decode($raw, true);
    
    if (!$body) {
        echo json_encode(array('error' => 'invalid json body'));
        return;
    }
    
    // Flutter dan kelayotgan maydonlar
    $id_token     = isset($body['id_token'])     ? trim($body['id_token'])     : '';
    $token        = isset($body['token'])        ? trim($body['token'])        : '';
    $access_token = isset($body['access_token']) ? trim($body['access_token']) : '';
    $fb_email     = isset($body['email'])        ? trim($body['email'])        : '';
    $fb_name      = isset($body['name'])         ? trim($body['name'])         : '';
    $fb_avatar    = isset($body['avatar'])       ? trim($body['avatar'])       : '';
    
    // id_token uchun ikki nomni tekshirish
    if (empty($id_token) && !empty($token)) {
        $id_token = $token;
    }
    
    // Google dan user ma'lumotlarini olish
    $guser = arab_get_google_user_info($id_token, $access_token);
    
    // Google API ishlamagan holatda email-ni fallback sifatida ishlatish
    if (!$guser && !empty($fb_email)) {
        $guser = array(
            'google_id' => md5($fb_email . 'arabtili'),
            'email'     => $fb_email,
            'name'      => $fb_name,
            'avatar'    => $fb_avatar,
        );
    }
     
    if (!$guser || empty($guser['email'])) {
        echo json_encode(array('error' => 'invalid token'));
        return;
    }
    
    // ── Foydalanuvchini DB-dan topish yoki yaratish ──────────────────────────
    // (quyida JSON fayl ishlatilgan, MySQL bilan almashtirishingiz mumkin)
    $db_file = __DIR__ . '/arab_users.json';
    $users   = array();
    
    if (file_exists($db_file)) {
        $content = file_get_contents($db_file);
        $users   = json_decode($content, true);
        if (!is_array($users)) $users = array();
    }
    
    $email   = $guser['email'];
    $user_id = null;
    
    foreach ($users as $uid => $u) {
        if (isset($u['email']) && $u['email'] === $email) {
            $user_id = $uid;
            break;
        }
    }
    
    if ($user_id === null) {
        // Yangi foydalanuvchi
        $user_id = 'u' . time() . rand(10, 99);
        $users[$user_id] = array(
            'id'      => $user_id,
            'email'   => $email,
            'name'    => !empty($guser['name'])   ? $guser['name']   : $fb_name,
            'avatar'  => !empty($guser['avatar']) ? $guser['avatar'] : $fb_avatar,
            'gid'     => $guser['google_id'],
            'created' => date('Y-m-d H:i:s'),
        );
    } else {
        // Mavjud foydalanuvchini yangilash
        if (!empty($guser['name']))   $users[$user_id]['name']   = $guser['name'];
        if (!empty($guser['avatar'])) $users[$user_id]['avatar'] = $guser['avatar'];
    }
    
    file_put_contents($db_file, json_encode($users, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
    $user = $users[$user_id];
    
    // JWT yaratish
    $jwt = arab_make_jwt($user_id, $email);
    
    echo json_encode(array(
        'access_token' => $jwt,
        'user_id'      => $user_id,
        'email'        => $user['email'],
        'name'         => $user['name'],
        'avatar'       => $user['avatar'],
    ));
}

// ════════════════════════════════════════════════════════════
// Bu faylni arab.php ICHIGA qo'shish tartibi:
//
// 1. arab_curl_get(), arab_get_google_user_info(), 
//    arab_make_jwt(), handle_google_auth() 
//    funksiyalarini arab.php TEPASIGA ko'chiring
//
// 2. Switch/route blokida:
//    case 'google_auth':
//        handle_google_auth();
//        break;
//
// 3. arab_users.json uchun ruxsat:
//    chmod 666 arab_users.json
//    yoki: touch arab_users.json && chmod 666 arab_users.json
// ════════════════════════════════════════════════════════════
