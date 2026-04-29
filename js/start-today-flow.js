/* ═══ StartTodayFlow controller ════════════════════════════════════════
   Pure orchestration — calls into existing globals defined in app.html
   (mpLoad, mpGetToday, appendFoodLogItem, showScreen, completeDay,
   getJourneyPhase, coachLine, getFutureYouCopy). No existing functions
   are renamed or removed. Step state persists to localStorage so the
   user can quit & resume.

   Loaded via <script src="/js/start-today-flow.js" defer> from app.html.
   The defer attribute guarantees the script runs after DOMContentLoaded,
   so injecting markup into <body> is safe. Existing localStorage keys
   ('wylde_stf_state', 'wylde_program', 'wylde_food_log_*', 'wylde_dash_*',
   'wylde_last_completed_day', 'wylde_profile', 'wylde_day') are unchanged.
*/
(function() {
  'use strict';

  var STORAGE_KEY = 'wylde_stf_state';
  var TOTAL_STEPS = 6;

  // ─── Markup injection ───────────────────────────────────────────
  // Builds the overlay DOM once at load time so app.html stays free of
  // STF-specific markup. Safe with defer: body is parsed by the time
  // this runs. Idempotent — if #stf-overlay already exists (e.g. dev
  // hot-reload), we reuse it.
  function ensureMarkup() {
    if (document.getElementById('stf-overlay')) return;
    var html =
      '<div id="stf-overlay" role="dialog" aria-modal="true" aria-labelledby="stf-title" aria-hidden="true">' +
        '<div class="stf-sheet">' +
          '<div class="stf-head">' +
            '<button class="stf-back" id="stf-back" type="button" aria-label="Back" onclick="window.STF && STF.back()">&#8249;</button>' +
            '<span class="stf-step-label" id="stf-step-label">Step 1 of 6</span>' +
            '<button class="stf-close" id="stf-close" type="button" aria-label="Close" onclick="window.STF && STF.close()">&times;</button>' +
          '</div>' +
          '<div class="stf-progress"><div class="stf-progress-fill" id="stf-progress-fill"></div></div>' +
          '<div class="stf-body" id="stf-body">' +

            '<section class="stf-step" data-step="1">' +
              '<p class="stf-eyebrow" id="stf-anchor-eyebrow">Day 1 · Foundation</p>' +
              '<h2 class="stf-title" id="stf-title">Let’s build momentum.</h2>' +
              '<p class="stf-sub" id="stf-anchor-sub">One clear day. One honest step. The work today is small, repeatable, and yours.</p>' +
            '</section>' +

            '<section class="stf-step" data-step="2">' +
              '<p class="stf-eyebrow">Morning Ritual</p>' +
              '<h2 class="stf-title">Start the day on purpose.</h2>' +
              '<p class="stf-sub" id="stf-ritual-sub">Check off each action. Keep it light. Keep it real.</p>' +
              '<ul class="stf-ritual-list" id="stf-ritual-list"></ul>' +
              '<p class="stf-ritual-feedback" id="stf-ritual-feedback"></p>' +
            '</section>' +

            '<section class="stf-step" data-step="3">' +
              '<p class="stf-eyebrow">Training</p>' +
              '<h2 class="stf-title" id="stf-train-title">Today’s session</h2>' +
              '<p class="stf-sub" id="stf-train-sub">Loading your training…</p>' +
              '<div class="stf-card" id="stf-train-card" style="display:none;">' +
                '<p class="stf-card-title" id="stf-train-name">—</p>' +
                '<p class="stf-card-sub" id="stf-train-meta">—</p>' +
              '</div>' +
            '</section>' +

            '<section class="stf-step" data-step="4">' +
              '<p class="stf-eyebrow">Nutrition</p>' +
              '<h2 class="stf-title">Fuel the version you’re building.</h2>' +
              '<p class="stf-sub" id="stf-nutri-sub">Protein is your anchor today. Keep it simple: protein, plants, carbs, water.</p>' +
              '<div class="stf-options">' +
                '<button class="stf-option" type="button" onclick="window.STF && STF.nutritionAction(\'log\')">' +
                  '<span>Log a meal</span><span class="stf-option-arrow">›</span>' +
                '</button>' +
                '<button class="stf-option" type="button" onclick="window.STF && STF.nutritionAction(\'photo\')">' +
                  '<span>Snap a meal photo</span><span class="stf-option-arrow">›</span>' +
                '</button>' +
                '<button class="stf-option" type="button" onclick="window.STF && STF.nutritionAction(\'plan\')">' +
                  '<span>View today’s meal plan</span><span class="stf-option-arrow">›</span>' +
                '</button>' +
              '</div>' +
              '<p class="stf-meta" style="font-style:italic;">Your next meal doesn’t need to be perfect. It needs to be aligned.</p>' +
            '</section>' +

            '<section class="stf-step" data-step="5">' +
              '<p class="stf-eyebrow">Future Self</p>' +
              '<h2 class="stf-title">A short check-in.</h2>' +
              '<p class="stf-sub" id="stf-future-line">The version of you 12 weeks from now is built by boring reps like this.</p>' +
              '<button class="stf-option" type="button" onclick="window.STF && STF.openCoach()" style="margin-bottom:6px;">' +
                '<span>Talk to your future self</span><span class="stf-option-arrow">›</span>' +
              '</button>' +
              '<p class="stf-meta">Optional — skip if you’re not in the mood today.</p>' +
            '</section>' +

            '<section class="stf-step" data-step="6">' +
              '<p class="stf-eyebrow">Close the Loop</p>' +
              '<h2 class="stf-title" id="stf-close-title">Lock it in.</h2>' +
              '<p class="stf-sub" id="stf-close-sub">Mark what you completed today.</p>' +
              '<div class="stf-checks" id="stf-checks"></div>' +
              '<div class="stf-final" id="stf-final" style="display:none;">' +
                '<div class="stf-final-icon">✓</div>' +
                '<h3 class="stf-title" style="font-size:20px;" id="stf-final-headline">Day complete.</h3>' +
                '<p class="stf-sub" id="stf-final-sub">Momentum logged.</p>' +
              '</div>' +
            '</section>' +

          '</div>' +
          '<div class="stf-foot" id="stf-foot">' +
            '<button class="stf-btn stf-btn-ghost" id="stf-skip" type="button" onclick="window.STF && STF.next()">Skip</button>' +
            '<button class="stf-btn stf-btn-primary" id="stf-primary" type="button" onclick="window.STF && STF.primary()">Begin</button>' +
          '</div>' +
        '</div>' +
      '</div>';
    var wrap = document.createElement('div');
    wrap.innerHTML = html;
    // append the single root child to body
    var root = wrap.firstChild;
    if (root) document.body.appendChild(root);
  }

  // ─── State ──────────────────────────────────────────────────────
  function todayKey() {
    return new Date().toISOString().slice(0, 10);
  }

  function loadState() {
    try {
      var raw = JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}');
      // Each new day starts fresh.
      if (raw.date !== todayKey()) raw = { date: todayKey(), step: 1 };
      if (!raw.step) raw.step = 1;
      return raw;
    } catch(_) {
      return { date: todayKey(), step: 1 };
    }
  }

  function saveState() {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); } catch(_) {}
  }

  var state = loadState();

  function $(id) { return document.getElementById(id); }
  function showStepEl(stepNum) {
    var steps = document.querySelectorAll('#stf-body .stf-step');
    steps.forEach(function(s) { s.classList.toggle('is-active', parseInt(s.dataset.step, 10) === stepNum); });
    $('stf-step-label').textContent = 'Step ' + stepNum + ' of ' + TOTAL_STEPS;
    $('stf-progress-fill').style.width = ((stepNum - 1) / (TOTAL_STEPS - 1) * 100) + '%';
    var back = $('stf-back');
    if (back) back.disabled = stepNum <= 1;
    renderStep(stepNum);
  }

  function setPrimaryButton(label, enabled) {
    var btn = $('stf-primary');
    if (!btn) return;
    btn.textContent = label || 'Continue';
    btn.disabled = enabled === false;
    btn.style.opacity = enabled === false ? '0.5' : '';
    btn.style.pointerEvents = enabled === false ? 'none' : '';
  }
  function setSkipVisible(visible) {
    var s = $('stf-skip'); if (s) s.style.display = visible ? '' : 'none';
  }

  // ─── Step renderers ─────────────────────────────────────────────
  function renderStep(n) {
    if (n === 1) renderAnchor();
    else if (n === 2) renderRitual();
    else if (n === 3) renderTraining();
    else if (n === 4) renderNutrition();
    else if (n === 5) renderFuture();
    else if (n === 6) renderCloseout();
  }

  function getDayNumber() {
    try {
      var stored = parseInt(localStorage.getItem('wylde_day') || '1', 10);
      return isNaN(stored) ? 1 : stored;
    } catch(_) { return 1; }
  }

  function renderAnchor() {
    var day = getDayNumber();
    var phase = (typeof window.getJourneyPhase === 'function') ? window.getJourneyPhase(day) : { name: 'Foundation' };
    $('stf-anchor-eyebrow').textContent = 'Day ' + day + ' · ' + phase.name;
    var titles = [
      'Let’s build momentum.',
      'Today sets the standard.',
      'One clear day. One honest step.',
      'Quiet work. Real progress.'
    ];
    var subs = [
      'The work today is small, repeatable, and yours.',
      'No hype. Just the next aligned action.',
      'You don’t need intensity today. You need consistency.',
      'Keep it simple: ritual, training, fuel, follow-through.'
    ];
    $('stf-title').textContent = titles[day % titles.length];
    $('stf-anchor-sub').textContent = subs[day % subs.length];
    setPrimaryButton('Begin', true);
    setSkipVisible(false);
  }

  function renderRitual() {
    var listEl = $('stf-ritual-list');
    if (!listEl) return;
    listEl.innerHTML = '';
    var data = (typeof window.mpLoad === 'function') ? window.mpLoad() : null;
    if (!data || !data.actions || !data.actions.length) {
      listEl.innerHTML = '<li style="font-size:13px;color:var(--text-muted, var(--muted));padding:14px 0;">No ritual set up yet. You can configure one from the Today screen anytime.</li>';
      $('stf-ritual-feedback').textContent = '';
      setPrimaryButton('Continue', true);
      setSkipVisible(true);
      return;
    }
    var today = (typeof window.mpGetToday === 'function') ? window.mpGetToday() : todayKey();
    var done = (data.completedDays && data.completedDays[today]) || {};
    data.actions.forEach(function(a) {
      var li = document.createElement('li');
      li.className = 'stf-ritual-item' + (done[a.id] ? ' done' : '');
      li.innerHTML =
        '<span class="stf-ritual-check">✓</span>' +
        '<span class="stf-ritual-name">' + (a.name || a.id) + '</span>';
      li.onclick = function() {
        // Toggle the action via the existing data shape — same source of truth
        // the Morning Protocol UI uses, so checks here update the Today screen.
        var d = (typeof window.mpLoad === 'function') ? window.mpLoad() : data;
        if (!d.completedDays[today]) d.completedDays[today] = {};
        var was = !!d.completedDays[today][a.id];
        if (was) {
          delete d.completedDays[today][a.id];
        } else {
          d.completedDays[today][a.id] = true;
        }
        if (typeof window.mpSave === 'function') window.mpSave(d);
        renderRitual();
        if (!was) {
          $('stf-ritual-feedback').textContent = (typeof window.coachLine === 'function')
            ? window.coachLine('ritualDone')
            : 'Good. That’s one.';
        }
      };
      listEl.appendChild(li);
    });
    setPrimaryButton('Continue', true);
    setSkipVisible(true);
  }

  function renderTraining() {
    var program = null;
    try { program = JSON.parse(localStorage.getItem('wylde_program') || 'null'); } catch(_) {}
    var card = $('stf-train-card');
    var sub = $('stf-train-sub');
    var nameEl = $('stf-train-name');
    var metaEl = $('stf-train-meta');
    var titleEl = $('stf-train-title');
    if (program && program.days && program.days.length) {
      var dayIdx = ((getDayNumber() - 1) % program.days.length + program.days.length) % program.days.length;
      var day = program.days[dayIdx] || program.days[0];
      var exCount = (day.exercises && day.exercises.length) || 0;
      var minutes = Math.max(20, exCount * 6);
      titleEl.textContent = 'Today’s session';
      sub.textContent = 'A short, focused block. Show up, do the reps, leave.';
      nameEl.textContent = day.name || day.title || ('Day ' + (dayIdx + 1));
      metaEl.textContent = (day.focus || day.type || 'Training') + ' · ' + exCount + ' exercises · ~' + minutes + ' min';
      card.style.display = 'block';
      setPrimaryButton('Start Training', true);
    } else {
      titleEl.textContent = 'Today’s session';
      sub.textContent = 'No program loaded yet — generate one to get started.';
      card.style.display = 'none';
      setPrimaryButton('Generate Today’s Training', true);
    }
    setSkipVisible(true);
  }

  function renderNutrition() {
    setPrimaryButton('Continue', true);
    setSkipVisible(true);
  }

  function renderFuture() {
    var day = getDayNumber();
    var week = Math.max(1, Math.ceil(day / 7));
    var copy = (typeof window.getFutureYouCopy === 'function') ? window.getFutureYouCopy(week) : 'The version of you 12 weeks from now is built by boring reps like this.';
    $('stf-future-line').textContent = copy;
    setPrimaryButton('Continue', true);
    setSkipVisible(true);
  }

  function renderCloseout() {
    // Mirror the same completion signals the Daily Closeout card uses,
    // reading from localStorage so we don't depend on IIFE-scoped globals.
    var checksEl = $('stf-checks');
    if (!checksEl) return;
    var today = todayKey();
    var alreadyDone = false;
    try { alreadyDone = localStorage.getItem('wylde_last_completed_day') === today; } catch(_) {}

    var mpDone = false;
    try {
      var mpData = (typeof window.mpLoad === 'function') ? window.mpLoad() : null;
      if (mpData && mpData.actions) {
        var td = (mpData.completedDays || {})[today] || {};
        mpDone = mpData.actions.every(function(a) { return td[a.id]; });
      }
    } catch(_) {}

    var sessionsDone = false;
    try {
      var sRef = (typeof window.state === 'object' && window.state) ? window.state : null;
      if (!sRef) sRef = JSON.parse(localStorage.getItem('wylde_profile') || '{}');
      sessionsDone = (sRef && sRef.sessions || 0) > 0;
    } catch(_) {}

    var nutritionDone = false;
    try {
      var todayFood = JSON.parse(localStorage.getItem('wylde_food_log_' + today) || '[]');
      var cal = 0; todayFood.forEach(function(f) { cal += (f.cal || 0); });
      nutritionDone = cal > 0;
    } catch(_) {}

    var waterDone = false;
    try {
      var d = JSON.parse(localStorage.getItem('wylde_dash_' + today) || '{}');
      waterDone = (d.water || 0) >= 64;
    } catch(_) {}

    var checks = [
      { label: 'Protocol',  done: mpDone },
      { label: 'Workout',   done: sessionsDone },
      { label: 'Nutrition', done: nutritionDone },
      { label: 'Water',     done: waterDone }
    ];
    checksEl.innerHTML = checks.map(function(c) {
      return '<span class="stf-check' + (c.done ? ' done' : '') + '">' +
        '<span class="stf-check-dot">' + (c.done ? '✓' : '') + '</span>' +
        c.label +
      '</span>';
    }).join('');

    if (alreadyDone) {
      $('stf-final').style.display = 'block';
      $('stf-final-headline').textContent = (typeof window.coachLine === 'function') ? window.coachLine('closeout') : 'Day complete.';
      $('stf-final-sub').textContent = 'You already closed today. Rest counts too.';
      setPrimaryButton('Done', true);
      setSkipVisible(false);
    } else {
      $('stf-final').style.display = 'none';
      setPrimaryButton('Close the Loop', true);
      setSkipVisible(false);
    }
  }

  // ─── Navigation ─────────────────────────────────────────────────
  function open() {
    var ov = $('stf-overlay');
    if (!ov) return;
    state = loadState();
    ov.classList.add('is-open');
    ov.setAttribute('aria-hidden', 'false');
    document.body.style.overflow = 'hidden';
    showStepEl(state.step || 1);
    setTimeout(function() {
      var btn = $('stf-primary');
      if (btn && typeof btn.focus === 'function') { try { btn.focus(); } catch(_) {} }
    }, 50);
  }

  function close() {
    var ov = $('stf-overlay');
    if (!ov) return;
    ov.classList.remove('is-open');
    ov.setAttribute('aria-hidden', 'true');
    document.body.style.overflow = '';
    saveState();
  }

  function next() {
    if (state.step >= TOTAL_STEPS) { close(); return; }
    state.step += 1;
    saveState();
    showStepEl(state.step);
  }

  function back() {
    if (state.step <= 1) return;
    state.step -= 1;
    saveState();
    showStepEl(state.step);
  }

  function primary() {
    if (state.step === 3) {
      close();
      if (typeof window.showScreen === 'function') window.showScreen('program');
      return;
    }
    if (state.step === 6) {
      var today = todayKey();
      var alreadyDone = false;
      try { alreadyDone = localStorage.getItem('wylde_last_completed_day') === today; } catch(_) {}
      if (alreadyDone) { close(); return; }
      if (typeof window.completeDay === 'function') {
        try { window.completeDay(); } catch(e) { console.warn('completeDay error:', e); }
      }
      $('stf-final').style.display = 'block';
      $('stf-final-headline').textContent = (typeof window.coachLine === 'function') ? window.coachLine('closeout') : 'Day complete.';
      $('stf-final-sub').textContent = 'Momentum logged.';
      setPrimaryButton('Done', true);
      saveState();
      return;
    }
    next();
  }

  function nutritionAction(kind) {
    close();
    if (kind === 'plan') {
      if (typeof window.showScreen === 'function') window.showScreen('nutrition');
    } else if (kind === 'photo') {
      if (typeof window.showScreen === 'function') window.showScreen('nutrition');
      setTimeout(function() {
        var photoBtn = document.getElementById('photoScanLabel') || document.querySelector('label[for="photoScan"]');
        if (photoBtn && photoBtn.scrollIntoView) photoBtn.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }, 200);
    } else {
      if (typeof window.showScreen === 'function') window.showScreen('nutrition');
      setTimeout(function() {
        var input = document.getElementById('foodLogInput');
        if (input) { input.focus(); input.scrollIntoView({ behavior: 'smooth', block: 'center' }); }
      }, 200);
    }
  }

  function openCoach() {
    close();
    if (typeof window.showScreen === 'function') window.showScreen('coach');
  }

  // ─── Wire up ────────────────────────────────────────────────────
  ensureMarkup();

  document.addEventListener('click', function(e) {
    if (e.target && e.target.id === 'stf-overlay') close();
  });

  document.addEventListener('keydown', function(e) {
    var ov = $('stf-overlay');
    if (!ov || !ov.classList.contains('is-open')) return;
    if (e.key === 'Escape') close();
  });

  window.STF = {
    open: open, close: close, next: next, back: back,
    primary: primary, nutritionAction: nutritionAction, openCoach: openCoach
  };
})();
