// Page served to the phone. Text is sent live as you type or dictate.
let phonePage = #"""
<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="theme-color" content="#000000">
<title>Islet</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin: 0; background: #000; color: #fff; font: 17px -apple-system, system-ui, sans-serif;
         padding: max(16px, env(safe-area-inset-top)) 16px max(16px, env(safe-area-inset-bottom));
         min-height: 100dvh; display: flex; flex-direction: column; gap: 12px; }
  header { display: flex; align-items: center; justify-content: space-between; }
  h1 { font-size: 20px; margin: 0; }
  #status { font-size: 13px; color: #8e8e93; display: flex; align-items: center; gap: 6px; }
  #dot { width: 8px; height: 8px; border-radius: 50%; background: #8e8e93; }
  #dot.ok { background: #30d158; } #dot.err { background: #ff453a; }
  textarea { flex: 1; min-height: 40dvh; width: 100%; resize: none; border: 1px solid #2c2c2e; border-radius: 18px;
             background: #1c1c1e; color: #fff; font-size: 22px; line-height: 1.35; padding: 16px; outline: none; }
  textarea:focus { border-color: #0a84ff; }
  .row { display: flex; gap: 10px; }
  button { flex: 1; border: 0; border-radius: 14px; padding: 15px; font-size: 17px; font-weight: 600;
           background: #2c2c2e; color: #fff; }
  button:active { opacity: .7; }
  #mic.on { background: #ff453a; }
  #send { background: #0a84ff; }
  label { display: flex; align-items: center; gap: 8px; color: #aeaeb2; font-size: 15px; }
  .hint { color: #8e8e93; font-size: 14px; line-height: 1.4; margin: 0; }
</style>
</head>
<body>
  <header>
    <h1>Islet</h1>
    <div id="status"><span id="dot"></span><span id="st">готово</span></div>
  </header>
  <textarea id="t" placeholder="Пиши или диктуй — текст сразу появится в вырезе на Mac" autofocus></textarea>
  <div class="row">
    <button id="clear">Очистить</button>
    <button id="mic" hidden>🎙 Слушать</button>
    <button id="send" hidden>Отправить</button>
  </div>
  <label><input type="checkbox" id="live" checked> Отправлять сразу, пока пишу</label>
  <p class="hint">Для живых субтитров нажми 🎤 на клавиатуре телефона и говори — текст будет идти на Mac по мере распознавания.</p>
<script>
  const ta = document.getElementById('t'), live = document.getElementById('live');
  const dot = document.getElementById('dot'), st = document.getElementById('st');
  const sendBtn = document.getElementById('send'), mic = document.getElementById('mic');
  let inflight = false, queued = false, lastSent = null;

  function status(ok, msg) { dot.className = ok ? 'ok' : 'err'; st.textContent = msg; }

  async function push(text) {
    if (inflight) { queued = true; return; }
    if (text === lastSent) return;
    inflight = true; lastSent = text;
    try {
      const r = await fetch('/text', { method: 'POST', body: text });
      status(r.ok, r.ok ? 'отправлено' : 'ошибка ' + r.status);
    } catch (e) { status(false, 'нет связи с Mac'); lastSent = null; }
    inflight = false;
    if (queued) { queued = false; push(ta.value); }
  }

  ta.addEventListener('input', () => { if (live.checked) push(ta.value); });
  live.addEventListener('change', () => { sendBtn.hidden = live.checked; });
  sendBtn.addEventListener('click', () => { lastSent = null; push(ta.value); });
  document.getElementById('clear').addEventListener('click', () => { ta.value = ''; push(''); ta.focus(); });

  // Built-in speech recognition only works on HTTPS, so on a plain LAN address
  // keyboard dictation is the main path. The button appears if the browser allows it.
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (SR && window.isSecureContext) {
    mic.hidden = false;
    const rec = new SR(); rec.lang = 'ru-RU'; rec.interimResults = true; rec.continuous = true;
    let on = false, base = '';
    rec.onresult = (e) => {
      let finalText = '', interim = '';
      for (const r of e.results) (r.isFinal ? (finalText += r[0].transcript) : (interim += r[0].transcript));
      ta.value = (base + finalText + interim).trim(); push(ta.value);
    };
    rec.onend = () => { if (on) rec.start(); };
    mic.addEventListener('click', () => {
      on = !on; mic.classList.toggle('on', on); mic.textContent = on ? '■ Стоп' : '🎙 Слушать';
      if (on) { base = ta.value ? ta.value + ' ' : ''; rec.start(); } else rec.stop();
    });
  }
</script>
</body>
</html>
"""#
