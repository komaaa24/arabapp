<?php
/**
 * DEBUG FAYLI — arab_debug.php
 * Serverga yuklang: http://luxcontent.uz/arab_debug.php
 * Flutter yoki Postman dan test qiling
 * TEST TUGAGACH — O'CHIRIB TASHLANG!
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit;
}

$route = isset($_GET['route']) ? $_GET['route'] : 'info';

// ─── So'rov ma'lumotlarini yig'ish ───────────────────────────────────────────
$input_raw  = file_get_contents('php://input');
$input_json = json_decode($input_raw, true);
$headers    = getallheaders();

$report = array(
    'route'          => $route,
    'method'         => $_SERVER['REQUEST_METHOD'],
    'php_version'    => PHP_VERSION,
    'input_raw_len'  => strlen($input_raw),
    'input_json'     => $input_json,
    'authorization'  => isset($headers['Authorization']) ? substr($headers['Authorization'], 0, 30).'...' : null,
    'content_type'   => isset($headers['Content-Type']) ? $headers['Content-Type'] : null,
);

// ─── Token mavjudligini tekshirish ───────────────────────────────────────────
if ($input_json) {
    $id_token     = isset($input_json['id_token'])     ? $input_json['id_token']     : (isset($input_json['token']) ? $input_json['token'] : '');
    $access_token = isset($input_json['access_token']) ? $input_json['access_token'] : '';

    $report['tokens'] = array(
        'id_token_length'     => strlen($id_token),
        'id_token_prefix'     => strlen($id_token) > 10 ? substr($id_token, 0, 20).'...' : 'EMPTY',
        'access_token_length' => strlen($access_token),
        'access_token_prefix' => strlen($access_token) > 10 ? substr($access_token, 0, 20).'...' : 'EMPTY',
        'email'               => isset($input_json['email'])  ? $input_json['email']  : '',
        'name'                => isset($input_json['name'])   ? $input_json['name']   : '',
        'avatar_len'          => isset($input_json['avatar']) ? strlen($input_json['avatar']) : 0,
    );

    // ─── Google tokeninfo API ni test qilish ─────────────────────────────────
    if ($id_token && strlen($id_token) > 50) {
        $url = 'https://oauth2.googleapis.com/tokeninfo?id_token=' . urlencode($id_token);
        
        if (function_exists('curl_init')) {
            $ch = curl_init($url);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_TIMEOUT, 8);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
            curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
            $tokeninfo_result = curl_exec($ch);
            $curl_error       = curl_error($ch);
            $curl_errno       = curl_errno($ch);
            curl_close($ch);

            $report['tokeninfo_test'] = array(
                'url'         => 'https://oauth2.googleapis.com/tokeninfo?id_token=...',
                'curl_error'  => $curl_error ?: null,
                'curl_errno'  => $curl_errno ?: null,
                'response_len'=> strlen($tokeninfo_result),
                'response'    => $tokeninfo_result ? json_decode($tokeninfo_result, true) : null,
            );
        } else {
            $report['tokeninfo_test'] = array('error' => 'curl mavjud emas');
        }
    }

    // ─── Google userinfo API ni access_token bilan test qilish ───────────────
    if ($access_token && strlen($access_token) > 10) {
        if (function_exists('curl_init')) {
            $ch = curl_init('https://www.googleapis.com/oauth2/v3/userinfo');
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_TIMEOUT, 8);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
            curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
            curl_setopt($ch, CURLOPT_HTTPHEADER, array('Authorization: Bearer ' . $access_token));
            $userinfo_result = curl_exec($ch);
            $curl_error2     = curl_error($ch);
            curl_close($ch);

            $report['userinfo_test'] = array(
                'curl_error' => $curl_error2 ?: null,
                'response'   => $userinfo_result ? json_decode($userinfo_result, true) : null,
            );
        }
    }
}

// ─── PHP curl imkoniyatlarini tekshirish ─────────────────────────────────────
$report['server_capabilities'] = array(
    'curl_enabled'   => function_exists('curl_init'),
    'openssl_enabled'=> extension_loaded('openssl'),
    'allow_url_fopen'=> ini_get('allow_url_fopen') ? true : false,
    'php_version'    => PHP_VERSION,
);

echo json_encode($report, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
