/* ============================================
   선두교회 신혼부부회 ｜ 스승의 주일 편지
   인터랙션 로직
   ============================================ */

(() => {
  'use strict';

  // ── DOM 참조 ──────────────────────────────
  const sceneWelcome = document.getElementById('scene-welcome');
  const sceneLetter  = document.getElementById('scene-letter');
  const sceneVideo   = document.getElementById('scene-video');
  const airplane     = document.getElementById('airplane');
  const tapHint      = document.getElementById('tapHint');
  const video        = document.getElementById('letterVideo');
  const videoFallback= document.getElementById('videoFallback');
  const replayBtn    = document.getElementById('replayBtn');
  const petalsBox    = document.getElementById('petals');

  let started = false;

  // ── 벚꽃 꽃잎 생성 ────────────────────────
  function spawnPetals(count = 24) {
    for (let i = 0; i < count; i++) {
      const p = document.createElement('div');
      p.className = 'petal';
      const size = 10 + Math.random() * 12;
      const dur  = 7 + Math.random() * 8;
      const delay = -Math.random() * 12;
      const drift = (Math.random() * 200 - 100) + 'px';
      p.style.width  = size + 'px';
      p.style.height = size + 'px';
      p.style.left   = Math.random() * 100 + 'vw';
      p.style.animationDuration = dur + 's';
      p.style.animationDelay    = delay + 's';
      p.style.setProperty('--drift', drift);
      p.style.opacity = 0.6 + Math.random() * 0.4;
      petalsBox.appendChild(p);
    }
  }
  spawnPetals();

  // ── 씬 전환 헬퍼 ──────────────────────────
  function showScene(scene) {
    [sceneWelcome, sceneLetter, sceneVideo].forEach(s => s.classList.remove('active'));
    scene.classList.add('active');
  }

  // ── 핵심: 첫 탭에서 모든 시퀀스 시작 ──────
  async function startSequence() {
    if (started) return;
    started = true;

    // 1) 영상 사용자 제스처 잠금 해제 (load + 살짝 재생/일시정지)
    //    이렇게 한 번 호출해두면 나중에 video.play()가 소리와 함께 자동 실행됨
    try {
      video.muted = false;
      video.volume = 1.0;
      // 살짝 load 트리거 — 즉시 play()는 안 함 (씬 전환 후에 재생)
      video.load();
    } catch (e) { /* noop */ }

    // 2) 환영 화면 페이드 (탭힌트/타이틀/교회) — 비행기 등장 직후
    sceneWelcome.classList.add('tapped');

    // 3) 종이비행기 — 멀리서 화면으로 날아옴 (2.6s)
    requestAnimationFrame(() => {
      airplane.classList.add('flying-in');
    });

    // 4) 비행기 도착 직전 편지 씬 활성화 (편지가 비행기 자리에 펼쳐짐)
    await wait(2400);
    airplane.classList.add('depart');
    document.body.classList.add('dim-bg'); // 배경 흐리게
    showScene(sceneLetter);

    // 5) 편지 펼침 + 글 읽는 시간
    await wait(4200);

    // 6) 영상 씬으로 전환 (배경 GPU 효과 제거 → 영상 디코딩 우선)
    document.body.classList.remove('dim-bg');
    document.body.classList.add('video-playing');
    showScene(sceneVideo);

    // 7) 영상 자동 재생 (소리 포함)
    //    첫 탭이 user gesture로 인정되므로 모바일에서도 작동
    console.log('[letter] video scene shown. readyState=', video.readyState, 'networkState=', video.networkState);
    try {
      await video.play();
      console.log('[letter] video.play() OK');
    } catch (err) {
      console.warn('[letter] 소리 자동재생 차단, 음소거로 재시도:', err);
      try {
        video.muted = true;
        await video.play();
        console.log('[letter] 음소거 재생 OK');
        showUnmutePrompt();
      } catch (err2) {
        console.error('[letter] 영상 재생 실패:', err2, 'video.error=', video.error);
        showFallback();
      }
    }
  }

  // ── 진단 로그 (브라우저 F12 콘솔에서 확인) ──
  ['loadstart', 'loadedmetadata', 'loadeddata', 'canplay', 'canplaythrough', 'playing', 'waiting', 'stalled', 'suspend', 'error'].forEach(evt => {
    video.addEventListener(evt, () => {
      console.log('[video]', evt, 'ready=', video.readyState, 'net=', video.networkState, 'src=', video.currentSrc);
    });
  });

  // ── 음소거 해제 안내 (예비용) ────────────
  function showUnmutePrompt() {
    const btn = document.createElement('button');
    btn.textContent = '🔊 소리 켜기';
    btn.style.cssText = `
      position: fixed; top: 20px; right: 20px; z-index: 99;
      background: #FFF9F5; color: #C9184A; border: none;
      padding: 10px 18px; border-radius: 20px;
      font-family: 'Gaegu', cursive; font-size: 15px; font-weight: 700;
      box-shadow: 0 4px 14px rgba(0,0,0,0.3); cursor: pointer;
    `;
    btn.addEventListener('click', () => {
      video.muted = false;
      btn.remove();
    }, { once: true });
    document.body.appendChild(btn);
  }

  // ── 영상 파일 없음 fallback ──────────────
  function showFallback() {
    videoFallback.hidden = false;
  }

  // ── 영상 fallback 정밀 제어 ─────────────────
  // stalled 는 정상 버퍼링 중에도 자주 발생 → fallback 트리거에서 제외
  // error 는 networkState 가 NO_SOURCE(3) 일 때만 진짜 실패
  video.addEventListener('error', () => {
    if (video.networkState === 3 || (video.error && video.error.code === 4)) {
      showFallback();
    }
  });
  // 재생 가능한 상태가 되면 fallback 강제로 숨김 (오발화 복구)
  ['loadeddata', 'canplay', 'playing'].forEach(evt => {
    video.addEventListener(evt, () => {
      if (!videoFallback.hidden) videoFallback.hidden = true;
    });
  });

  // ── 영상 종료 → 다시 보기 버튼 ────────────
  video.addEventListener('ended', () => {
    replayBtn.classList.add('show');
  });
  replayBtn.addEventListener('click', () => {
    replayBtn.classList.remove('show');
    video.currentTime = 0;
    video.play().catch(() => {});
  });

  // ── 첫 탭 리스너 (전역) ───────────────────
  function onFirstTap(e) {
    e.preventDefault();
    startSequence();
    document.removeEventListener('click', onFirstTap);
    document.removeEventListener('touchstart', onFirstTap);
  }
  document.addEventListener('click', onFirstTap, { once: true });
  document.addEventListener('touchstart', onFirstTap, { passive: false });

  // ── 유틸 ──────────────────────────────────
  function wait(ms) { return new Promise(r => setTimeout(r, ms)); }
})();
