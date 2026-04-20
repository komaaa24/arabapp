<?php
/**
 * ARAB.PHP GA QO'SHISH KERAK BO'LGAN PROGRESS ROUTELARI
 * PHP 5.6+ bilan ishlaydi
 *
 * Routelar:
 *   POST ?route=complete_lesson  → darsni yakunlash, XP/level/streak qaytaradi
 *   POST ?route=progress         → progress saqlash
 *   POST ?route=answer           → javobni tekshirish va saqlash
 *   GET  ?route=user_xp          → foydalanuvchi XP va statistikasini olish
 *
 * ISHLATISH:
 *   Quyidagi funksiyalarni arab.php ga ko'chiring va switch/route
 *   blokiga case'larni qo'shing (pastda ko'rsatilgan).
 */

// ─── Progress DB yordamchi funksiyalar ─────────────────────────────────────

function progress_load() {
    $f = __DIR__ . '/arab_progress.json';
    if (!file_exists($f)) return array();
    $d = json_decode(file_get_contents($f), true);
    return is_array($d) ? $d : array();
}

function progress_save($data) {
    file_put_contents(
        __DIR__ . '/arab_progress.json',
        json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE)
    );
}

function progress_get_user($uid) {
    $all = progress_load();
    if (!isset($all[$uid])) {
        $all[$uid] = array(
            'uid'              => $uid,
            'xp'               => 0,
            'level'            => 1,
            'streak'           => 0,
            'last_active_date' => '',
            'completed_lessons'=> array(),
            'answers'          => array(),
            'updated'          => time(),
        );
        progress_save($all);
    }
    return $all[$uid];
}

function progress_save_user($uid, $user_data) {
    $all = progress_load();
    $user_data['updated'] = time();
    $all[$uid] = $user_data;
    progress_save($all);
}

// XP dan daraja hisoblash (Flutter bilan mos: level = floor(sqrt(xp/10)))
function xp_to_level($xp) {
    if ($xp <= 0) return 1;
    $lvl = (int) floor(sqrt($xp / 10.0));
    return max(1, $lvl);
}

// Streak hisoblash (bugun yoki kecha aktiv bo'lsa streak davom etadi)
function calc_streak($user_data) {
    $today     = date('Y-m-d');
    $last_date = isset($user_data['last_active_date']) ? $user_data['last_active_date'] : '';
    $streak    = isset($user_data['streak']) ? (int)$user_data['streak'] : 0;

    if ($last_date === $today) {
        return $streak; // Bugun allaqachon hisoblangan
    }

    $yesterday = date('Y-m-d', strtotime('-1 day'));
    if ($last_date === $yesterday) {
        return $streak + 1; // Ketma-ket
    }

    return 1; // Yangi streak
}

// ─── ROUTE: complete_lesson ────────────────────────────────────────────────
// POST ?route=complete_lesson
// Body (JSON): { "user_id": "u123...", "lesson_id": 5, "score": 80 }
// Response:    { "status": "ok", "xp": 250, "level": 3, "streak": 4,
//               "xp_earned": 18, "lesson_id": 5 }

function route_complete_lesson() {
    header('Content-Type: application/json; charset=utf-8');

    $body      = json_decode(file_get_contents('php://input'), true);
    $uid       = isset($body['user_id'])  ? trim($body['user_id'])  : '';
    $lesson_id = isset($body['lesson_id'])? (int)$body['lesson_id'] : 0;
    $score     = isset($body['score'])    ? (int)$body['score']     : 100;

    if (empty($uid)) {
        echo json_encode(array('error' => 'user_id required'));
        exit;
    }

    $user = progress_get_user($uid);

    // Allaqachon tugallangan darslarda XP berilmaydi
    $already_done = in_array($lesson_id, (array)$user['completed_lessons']);
    $xp_earned    = 0;

    if (!$already_done && $lesson_id > 0) {
        // XP formula: 10 (baza) + score/10
        $xp_earned = 10 + (int)floor($score / 10);
        $user['xp'] = (int)$user['xp'] + $xp_earned;
        $user['completed_lessons'][] = $lesson_id;
    }

    // Streak yangilash
    $user['streak']           = calc_streak($user);
    $user['last_active_date'] = date('Y-m-d');
    $user['level']            = xp_to_level($user['xp']);

    progress_save_user($uid, $user);

    echo json_encode(array(
        'status'    => 'ok',
        'xp'        => (int)$user['xp'],
        'level'     => (int)$user['level'],
        'streak'    => (int)$user['streak'],
        'xp_earned' => $xp_earned,
        'lesson_id' => $lesson_id,
    ));
    exit;
}

// ─── ROUTE: progress ──────────────────────────────────────────────────────
// POST ?route=progress
// Body (JSON): { "user_id": "u123...", "lesson_id": 5, "score": 80 }
// Response:    { "status": "saved" }

function route_progress() {
    header('Content-Type: application/json; charset=utf-8');

    $body      = json_decode(file_get_contents('php://input'), true);
    $uid       = isset($body['user_id'])  ? trim($body['user_id'])  : '';
    $lesson_id = isset($body['lesson_id'])? (int)$body['lesson_id'] : 0;
    $score     = isset($body['score'])    ? (int)$body['score']     : 0;

    if (empty($uid)) {
        echo json_encode(array('error' => 'user_id required'));
        exit;
    }

    $user = progress_get_user($uid);

    // Progress logini saqlash
    if (!isset($user['lesson_scores'])) {
        $user['lesson_scores'] = array();
    }
    $user['lesson_scores'][$lesson_id] = array(
        'score' => $score,
        'date'  => date('Y-m-d H:i:s'),
    );

    progress_save_user($uid, $user);

    echo json_encode(array('status' => 'saved'));
    exit;
}

// ─── ROUTE: answer ────────────────────────────────────────────────────────
// POST ?route=answer
// Body (JSON): { "user_id": "u123...", "exercise_id": 3, "answer": "ba" }
// Response:    { "correct": true/false }

function route_answer() {
    header('Content-Type: application/json; charset=utf-8');

    $body        = json_decode(file_get_contents('php://input'), true);
    $uid         = isset($body['user_id'])     ? trim($body['user_id'])     : '';
    $exercise_id = isset($body['exercise_id']) ? (int)$body['exercise_id'] : 0;
    $answer      = isset($body['answer'])      ? trim($body['answer'])      : '';

    if (empty($uid)) {
        echo json_encode(array('error' => 'user_id required'));
        exit;
    }

    // Javobni logga saqlash (hozircha to'g'ri/noto'g'ri serverda tekshirilmaydi)
    $user = progress_get_user($uid);

    if (!isset($user['answers'])) {
        $user['answers'] = array();
    }
    $user['answers'][] = array(
        'exercise_id' => $exercise_id,
        'answer'      => $answer,
        'date'        => date('Y-m-d H:i:s'),
    );
    // Faqat oxirgi 200 ta javobni saqlash
    if (count($user['answers']) > 200) {
        $user['answers'] = array_slice($user['answers'], -200);
    }

    progress_save_user($uid, $user);

    // Hozircha har doim true qaytaramiz — to'g'ri javob tekshiruvi
    // frontendda amalga oshirilgan
    echo json_encode(array('correct' => true));
    exit;
}

// ─── ROUTE: user_xp ───────────────────────────────────────────────────────
// GET ?route=user_xp&user_id=u123...
// Response: { "user_id": "u123...", "xp": 250, "level": 3, "streak": 4,
//             "completed_lessons": [1,2,3,...] }

function route_user_xp() {
    header('Content-Type: application/json; charset=utf-8');

    $uid = isset($_GET['user_id']) ? trim($_GET['user_id']) : '';

    if (empty($uid)) {
        echo json_encode(array('error' => 'user_id required'));
        exit;
    }

    $user = progress_get_user($uid);

    echo json_encode(array(
        'user_id'           => $uid,
        'xp'                => (int)$user['xp'],
        'level'             => (int)$user['level'],
        'streak'            => (int)$user['streak'],
        'completed_lessons' => array_values((array)$user['completed_lessons']),
        'last_active'       => $user['last_active_date'],
    ));
    exit;
}

/*
 * ════════════════════════════════════════════════════════════════
 *  ARAB.PHP GA QO'SHISH TARTIBI:
 * ════════════════════════════════════════════════════════════════
 *
 * 1. Yuqoridagi BARCHA funksiyalarni arab.php ga ko'chiring
 *
 * 2. Route handling qismiga qo'shing:
 *
 *    switch ($route) {
 *        // ... mavjud routelar ...
 *
 *        case 'complete_lesson':
 *            route_complete_lesson();
 *            break;
 *
 *        case 'progress':
 *            route_progress();
 *            break;
 *
 *        case 'answer':
 *            route_answer();
 *            break;
 *
 *        case 'user_xp':
 *            route_user_xp();
 *            break;
 *    }
 *
 * 3. arab_progress.json fayliga yozish ruxsati bering:
 *    touch arab_progress.json
 *    chmod 666 arab_progress.json
 *
 * ════════════════════════════════════════════════════════════════
 *  TEST:
 *
 *  # Darsni yakunlash
 *  curl -X POST "http://luxcontent.uz/arab.php?route=complete_lesson" \
 *       -H "Content-Type: application/json" \
 *       -d '{"user_id":"u123","lesson_id":1,"score":80}'
 *  → {"status":"ok","xp":18,"level":1,"streak":1,"xp_earned":18}
 *
 *  # XP ni ko'rish
 *  curl "http://luxcontent.uz/arab.php?route=user_xp&user_id=u123"
 *  → {"user_id":"u123","xp":18,"level":1,"streak":1,"completed_lessons":[1]}
 * ════════════════════════════════════════════════════════════════
 */
