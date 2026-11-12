// Plays the ob-v2 mock as one phone, the way a new person would go through it. Open ob-v2.html?play
(async () => {
if (!location.search.includes('play')) return;
await document.fonts.ready;
const $ = (s, r = document) => r.querySelector(s), $$ = (s, r = document) => [...r.querySelectorAll(s)];
const sleep = ms => new Promise(r => setTimeout(r, ms));
const A = (el, k, o) => el.animate(k, Object.assign({ fill: 'forwards' }, o)).finished;
const spring = 'cubic-bezier(.2,1.4,.4,1)';
const byText = (root, t) => $$('*', root).find(e => e.children.length === 0 && e.textContent.trim() === t) || $$('div', root).find(e => e.textContent.trim().startsWith(t));

const phones = $$('.phone');
document.body.innerHTML = '';
document.body.style.cssText = 'background:#1b1a18;margin:0;padding:0;width:100vw;height:100vh;display:grid;place-items:center;align-content:center;gap:16px';
const cap = document.createElement('div');
cap.style.cssText = 'font:800 22px Archivo;font-stretch:85%;color:#F2ECE1;height:30px;text-align:center;letter-spacing:.3px';
const stage = document.createElement('div');
stage.style.cssText = 'position:relative;width:393px;height:852px;border-radius:52px;overflow:hidden;box-shadow:0 0 0 10px #000,0 0 0 12px #3a3a3a';
document.body.append(cap, stage);
phones.forEach(p => { p.style.position = 'absolute'; p.style.inset = '0'; p.style.display = 'none'; p.style.borderRadius = '0'; stage.appendChild(p); });
const tap = document.createElement('div');
tap.style.cssText = 'position:absolute;width:48px;height:48px;margin:-24px 0 0 -24px;border-radius:50%;border:3px solid #fff;background:#ffffff40;box-shadow:0 0 0 2px #0004;z-index:99;opacity:0;pointer-events:none';
stage.appendChild(tap);
const say = t => { cap.textContent = t; };

async function tapAt(el, hold = 0) {
  const s = stage.getBoundingClientRect(), r = el.getBoundingClientRect();
  tap.style.left = (r.left - s.left + r.width / 2) + 'px'; tap.style.top = (r.top - s.top + r.height / 2) + 'px';
  await A(tap, [{ opacity: 0, transform: 'scale(1.6)' }, { opacity: 1, transform: 'scale(1)' }], { duration: 220 });
  const press = A(el, [{ transform: getComputedStyle(el).transform === 'none' ? 'scale(1)' : getComputedStyle(el).transform }, { transform: (getComputedStyle(el).transform === 'none' ? '' : getComputedStyle(el).transform) + ' scale(.95)' }], { duration: 120, fill: 'none', direction: 'alternate', iterations: 2 });
  if (hold) await sleep(hold); else await press;
  await A(tap, [{ opacity: 1 }, { opacity: 0 }], { duration: 160 });
}

// ---------- set every slide to its "before" state ----------
const [s1, s2, sWhy, sRev, s3, s4, s5, s6, s7, s9, s10, s11] = phones;
const qnum = $('.qnum', s1), you1 = $('.marker', s1), arrow1 = $$('svg', s1)[0], take1 = byText(s1, 'Take a guess.');
you1.style.opacity = 0; arrow1.style.opacity = 0; take1.style.opacity = 0;

const tab3 = $$('.tabs div', s2)[1]; tab3.classList.remove('torn'); tab3.innerHTML = '<b>3&ndash;4 HRS</b>';
const loose = $$('.abs', s2).find(e => e.style.width === '76px'); loose.style.opacity = 0;
const honest = $('.stamp', s2); honest.style.opacity = 0;

// slide 5 is the heart-monitor brain (brain-v2.html), played live inside the phone
s3.innerHTML = ''; s3.style.background = '#0B1A16';
const brainFrame = document.createElement('iframe');
brainFrame.style.cssText = 'position:absolute;inset:0;width:393px;height:852px;border:0';
const brainBtn = document.createElement('div');
brainBtn.style.cssText = 'position:absolute;left:28px;right:28px;bottom:26px;height:56px;border-radius:28px';
s3.append(brainFrame, brainBtn);
const brainDone = new Promise(res => addEventListener('message', e => { if (e.data === 'brain-done') res(); }));

const stickers = $$('.st', s4); const onStick = stickers.filter(e => e.classList.contains('on'));
onStick.forEach(e => { e.classList.remove('on'); $('.chk', e).style.opacity = 0; });

const days = byText(s5, '94 DAYS'); const cells = $$('.cal i', s5); cells.forEach(c => c.className = '');
const good = $$('.abs', s5).find(e => e.textContent.includes('Cut it in half')); good.style.opacity = 0;

const boxes = $$('.box', s6); const onBox = boxes.filter(b => b.classList.contains('on')); onBox.forEach(b => b.classList.remove('on'));
const ring6 = $$('svg', s6)[0]; ring6.style.opacity = 0;

const paper7 = $('.tape2', s7); const lines7 = [...paper7.children]; lines7.forEach(l => l.style.opacity = 0); paper7.style.clipPath = 'inset(0 0 100% 0)';

const blank = $('.blank', sWhy); blank.style.clipPath = 'inset(0 0 100% 0)';
const whyRows = [...$('.why', sWhy).children]; whyRows.forEach(r => r.style.opacity = 0);
const rc2 = $('.rc2', sRev), big = $('.bignum', sRev), wow = $('.h', sRev), stampR = $('.stamp', sRev);
const yearR = byText(sRev, 'That’s 94 days a year.');
rc2.style.clipPath = 'inset(0 0 100% 0)'; stampR.style.opacity = 0; yearR.style.opacity = 0; wow.style.opacity = 0; big.textContent = '0H 00M';

const fill9 = $('.hold i', s9), sig9 = $('.sig b', s9); fill9.style.width = '0%'; sig9.style.clipPath = 'inset(0 100% 0 0)';

const card10 = $('.card', s10), tl10 = [...$('.tl', s10).children]; card10.style.opacity = 0; tl10.forEach(t => t.style.opacity = 0);

const ring11 = $$('circle', s11)[1], clock11 = byText(s11, '25:00'), quiet11 = byText(s11, 'Quiet now.');
ring11.style.strokeDashoffset = 804; quiet11.style.opacity = 0;

// ---------- home screen ----------
const home = document.createElement('div');
home.style.cssText = 'position:absolute;inset:0;background:radial-gradient(120% 80% at 30% 20%,#3b3f52,#121318);z-index:50';
let grid = '<div style="position:absolute;left:26px;right:26px;top:90px;display:grid;grid-template-columns:repeat(4,1fr);gap:26px 22px">';
const tint = ['#5a6070', '#4b5262', '#606878', '#535a6a'];
for (let i = 0; i < 20; i++) {
  if (i === 9) grid += '<div style="text-align:center"><div id="lockicon" style="aspect-ratio:1;border-radius:16px;background:#FF4A1C;display:grid;place-items:center;font:900 15px/0.9 Archivo;font-stretch:62%;color:#15120F;text-align:center">LOCK<br>IN</div><div style="font:500 11px system-ui;color:#fff;margin-top:6px">Lock In</div></div>';
  else grid += `<div style="text-align:center"><div style="aspect-ratio:1;border-radius:16px;background:${tint[i % 4]};opacity:.75"></div><div style="height:9px;margin:8px auto 0;width:60%;border-radius:4px;background:#ffffff30"></div></div>`;
}
home.innerHTML = grid + '</div><div style="position:absolute;top:18px;left:34px;font:600 16px system-ui;color:#fff">9:41</div>';
stage.appendChild(home);

let cur = null;
async function show(p) {
  if (cur) { await A(cur, [{ transform: 'none', opacity: 1 }, { transform: 'translateX(-60px)', opacity: 0 }], { duration: 260, easing: 'ease-in' }); cur.style.display = 'none'; }
  cur = p; p.style.display = 'block';
  const kids = [...p.children].filter(k => !k.classList.contains('island') && !k.classList.contains('sb') && !k.classList.contains('bars'));
  await Promise.all(kids.map((k, i) => {
    const op = k.style.opacity === '' ? 1 : +k.style.opacity; const tr = k.style.transform || '';
    return A(k, [{ transform: tr + ' translateY(26px)', opacity: 0 }, { transform: tr || 'none', opacity: op }], { duration: 480, delay: i * 55, easing: spring, fill: 'none' });
  }));
}
const pop = (el, rot = 0) => { el.style.opacity = 1; return A(el, [{ opacity: 0, transform: `rotate(${rot}deg) scale(.4)` }, { opacity: 1, transform: `rotate(${rot}deg) scale(1)` }], { duration: 420, easing: spring }); };
const btn = p => $('.btn', p) || $('.hold', p);

// ---------- the run ----------
say('A new person opens Lock In');
await sleep(1200);
await tapAt($('#lockicon'));
s1.style.display = 'block'; cur = s1;
const ic = $('#lockicon').getBoundingClientRect(), st = stage.getBoundingClientRect();
await A(home, [{ clipPath: `inset(${ic.top - st.top}px ${st.right - ic.right}px ${st.bottom - ic.bottom}px ${ic.left - st.left}px round 16px)`, opacity: 1 }, { clipPath: 'inset(0 0 0 0 round 0)', opacity: 0 }], { duration: 450, easing: 'ease-in' });
home.remove();

say('1. How many hours do you lose?');
await sleep(300);
for (let i = 0; i < 14; i++) { qnum.textContent = (1 + Math.floor(Math.random() * 9)) + 'H ' + String(Math.floor(Math.random() * 60)).padStart(2, '0') + 'M'; await sleep(90); }
qnum.textContent = '?H ??M';
await A(qnum, [{ transform: 'scale(1.06)' }, { transform: 'scale(1)' }], { duration: 300, easing: spring });
arrow1.style.opacity = 1; await A(arrow1, [{ clipPath: 'inset(0 0 0 100%)' }, { clipPath: 'inset(0 0 0 0)' }], { duration: 450 });
await pop(you1, -6);
await A(take1, [{ opacity: 0 }, { opacity: 1 }], { duration: 400 });
await sleep(1300); await tapAt(btn(s1));

say('2. They guess: tear off a tab');
await show(s2); await sleep(900);
await tapAt(tab3);
tab3.classList.add('torn'); tab3.innerHTML = '';
loose.style.opacity = 1;
await A(loose, [{ transform: 'translate(-110px,250px) rotate(0deg)' }, { transform: 'rotate(9deg)' }], { duration: 650, easing: spring });
await pop(honest, -4); await sleep(1100); await tapAt(btn(s2));

say('3. Now let\u2019s check: why we ask');
await show(sWhy); await sleep(300);
await A(blank, [{ clipPath: 'inset(0 0 100% 0)' }, { clipPath: 'inset(0 0 0% 0)' }], { duration: 1100, easing: 'steps(10,end)' });
for (const r of whyRows) { r.style.opacity = 1; await A(r, [{ opacity: 0, transform: 'translateX(-12px)' }, { opacity: 1, transform: 'none' }], { duration: 300 }); await sleep(450); }
await sleep(1400); await tapAt(btn(sWhy));
const sys = document.createElement('div');
sys.style.cssText = 'position:absolute;inset:0;background:#0006;display:grid;place-items:center;z-index:60';
sys.innerHTML = '<div style="width:270px;border-radius:14px;background:#2c2c2e;color:#fff;text-align:center;font:13px system-ui;overflow:hidden"><div style="padding:18px 16px 14px"><b style="font-size:17px">“Lock In” Would Like to Access Screen Time</b><div style="margin-top:6px;opacity:.8">Providing access may allow it to see your activity data and restrict content.</div></div><div style="display:flex;border-top:1px solid #444"><div style="flex:1;padding:12px;color:#0a84ff">Don’t Allow</div><div id="allow" style="flex:1;padding:12px;color:#0a84ff;font-weight:600;border-left:1px solid #444">Continue</div></div></div>';
sWhy.appendChild(sys); await A(sys, [{ opacity: 0 }, { opacity: 1 }], { duration: 220 });
await sleep(1000); await tapAt($('#allow', sys)); await A(sys, [{ opacity: 1 }, { opacity: 0 }], { duration: 200 }); sys.remove();

say('4. Guess vs. truth. Oh wow.');
await show(sRev); await sleep(200);
await A(rc2, [{ clipPath: 'inset(0 0 100% 0)' }, { clipPath: 'inset(0 0 0% 0)' }], { duration: 1800, easing: 'steps(14,end)' });
const t0 = performance.now();
await new Promise(res => { const step = () => { const k = Math.min(1, (performance.now() - t0) / 1300), e = 1 - Math.pow(1 - k, 3), m = Math.round(372 * e); big.textContent = Math.floor(m / 60) + 'H ' + String(m % 60).padStart(2, '0') + 'M'; k < 1 ? requestAnimationFrame(step) : res(); }; step(); });
await pop(wow, 0); await sleep(250); await pop(stampR, -9);
await A(yearR, [{ opacity: 0 }, { opacity: 1 }], { duration: 400 });
await sleep(1800); await tapAt(btn(sRev));

say('5. Their brain takes the hits');
brainFrame.src = 'brain-v2.html?play&hits=5&hours=6.2&title=' + encodeURIComponent('6h 12m a day.');
await new Promise(res => brainFrame.onload = res);
await show(s3);
await brainDone; await tapAt(brainBtn);

say('6. They peel the apps that pull them in');
await show(s4); await sleep(700);
for (const s of onStick) { await tapAt(s); s.classList.add('on'); const c = $('.chk', s); await pop(c); await sleep(250); }
await sleep(700); await tapAt(btn(s4));

say('7. Their next year: bad news, then good news');
await show(s5); await sleep(300);
for (let k = 0; k <= 94; k += 3) { days.textContent = k + ' DAYS'; for (let i = 0; i < k; i++) cells[i].className = 'x'; await sleep(28); }
days.textContent = '94 DAYS'; for (let i = 0; i < 94; i++) cells[i].className = 'x';
await sleep(900);
for (let i = 0; i < 47; i++) { cells[i].className = 'k'; if (i % 3 === 0) await sleep(16); }
good.style.opacity = 1; await A(good, [{ opacity: 0, transform: 'translateY(12px)' }, { opacity: 1, transform: 'none' }], { duration: 420 });
await sleep(1500); await tapAt(btn(s5));

say('8. They pick what to do with the time');
await show(s6); await sleep(700);
for (const b of onBox) { await tapAt(b); b.classList.add('on'); await sleep(300); }
ring6.style.opacity = 1; await A(ring6, [{ clipPath: 'inset(0 100% 0 0)' }, { clipPath: 'inset(0 0 0 0)' }], { duration: 500 });
await sleep(800); await tapAt(btn(s6));

say('9. Their plan prints from their answers');
await show(s7);
await A(paper7, [{ clipPath: 'inset(0 0 100% 0)' }, { clipPath: 'inset(0 0 0% 0)' }], { duration: 600 });
for (const l of lines7) { l.style.opacity = 1; await sleep(380); }
await sleep(700);

say('10. They sign a promise: hold to sign');
await show(s9); await sleep(800);
const holdBtn = btn(s9);
const s = stage.getBoundingClientRect(), r = holdBtn.getBoundingClientRect();
tap.style.left = (r.left - s.left + r.width / 2) + 'px'; tap.style.top = (r.top - s.top + r.height / 2) + 'px';
await A(tap, [{ opacity: 0, transform: 'scale(1.6)' }, { opacity: 1, transform: 'scale(.9)' }], { duration: 220 });
await Promise.all([A(fill9, [{ width: '0%' }, { width: '100%' }], { duration: 2000, easing: 'linear' }), A(sig9, [{ clipPath: 'inset(0 100% 0 0)' }, { clipPath: 'inset(0 0 0 0)' }], { duration: 1900, delay: 100, easing: 'ease-in-out' })]);
await A(tap, [{ opacity: 1 }, { opacity: 0 }], { duration: 160 });
await sleep(900);

say('11. The offer: honest trial, try for $0');
await show(s10);
await pop(card10, -4);
for (const t of tl10) { t.style.opacity = 1; await A(t, [{ opacity: 0, transform: 'translateX(-14px)' }, { opacity: 1, transform: 'none' }], { duration: 300 }); await sleep(260); }
await sleep(1500); await tapAt(btn(s10));

say('12. Locked in. Quiet now.');
await show(s11);
await A(ring11, [{ strokeDashoffset: 804 }, { strokeDashoffset: 20 }], { duration: 1600, easing: 'ease-out' });
await A(quiet11, [{ opacity: 0 }, { opacity: 1 }], { duration: 500 });
for (const t of ['24:59', '24:58', '24:57']) { await sleep(1000); clock11.textContent = t; }
await sleep(800);
say('');
window.__done = true;
})();
