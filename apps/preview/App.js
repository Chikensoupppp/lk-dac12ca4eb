import { useEffect, useRef, useState } from 'react';
import { Animated, Easing, Image, PanResponder, Pressable, SafeAreaView, StatusBar, StyleSheet, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

// A phone preview of the Nogbox first-run tutorial. It only shows the design and the words.
// The real app is SwiftUI; this is so the design can be tried on a phone without a build.

const C = { paper: '#F6F3EC', ink: '#171513', soft: '#6F6A60', line: '#E4DED3', inset: '#EDE9E0', amber: '#A97029' };
const brain = require('./assets/brain.png');

// act: the user taps the real control. Otherwise the card has Next.
const STEPS = [
  { id: 'task', text: "Hi, I'm your brain! What are we working on?", glow: 'task', pos: 'up', act: true },
  { id: 'minutes', text: '25 minutes is a great start. Tap it.', glow: 'seg', pos: 'up', act: true },
  { id: 'apps', text: "Which apps steal your time? I'll lock them up.", glow: 'shield', pos: 'down', act: true },
  { id: 'mode', text: 'Tap Locked mode. It hides the quit button.', glow: 'mode', pos: 'up', act: true },
  { id: 'goal', text: "Tap the target. Pick a weekly goal.", glow: 'goal', pos: 'down', act: true },
  { id: 'partner', text: 'Tap the friends icon. Bring a buddy.', glow: 'partner', pos: 'down', act: true },
  { id: 'pc', text: 'On a PC too? Tap Connect a PC.', glow: 'pc', pos: 'down', act: true },
  { id: 'live', text: 'I stay on your lock screen. Peek anytime.', preview: 'live', pos: 'down' },
  { id: 'widget', text: "Put me on your home screen. I'll watch your apps.", preview: 'widget', pos: 'down' },
  { id: 'streak', text: 'One session a day grows your streak. Easy wins!', preview: 'streak', pos: 'down' },
  { id: 'report', text: "Every Sunday, I'll show you how your week went.", preview: 'report', pos: 'down' },
  { id: 'quit', text: 'Need out? Hold to quit, or ask your friend. No judgment.', preview: 'quit', pos: 'down' },
  { id: 'plus', text: 'Want more? Plus unlocks Locked mode and PC pairing.', preview: 'plus', pos: 'down' },
  { id: 'hold', text: "Ready? Slide to lock in!", glow: 'btn', pos: 'up', act: true },
];

function Glow({ on, style, children }) {
  return (
    <View style={[style, on && styles.glow]}>
      {children}
    </View>
  );
}

function Preview({ kind }) {
  if (kind === 'live')
    return (
      <View style={[styles.pv, { backgroundColor: C.ink, flexDirection: 'row', alignItems: 'center', gap: 10, padding: 10, borderRadius: 18 }]}>
        <Image source={brain} style={{ width: 30, height: 26 }} resizeMode="contain" />
        <Text style={{ color: '#bbb', fontSize: 12, flex: 1 }}>Studying</Text>
        <Text style={{ color: C.paper, fontSize: 18, fontWeight: '700' }}>24:31</Text>
      </View>
    );
  if (kind === 'widget')
    return (
      <View style={[styles.pv, { width: 64, height: 64, borderRadius: 20, backgroundColor: C.inset, borderWidth: 1, borderColor: C.line, alignItems: 'center', justifyContent: 'center' }]}>
        <Image source={brain} style={{ width: 44, height: 38 }} resizeMode="contain" />
      </View>
    );
  if (kind === 'streak')
    return (
      <View style={[styles.pv, { flexDirection: 'row', alignItems: 'center', gap: 8 }]}>
        <Ionicons name="flame" size={28} color={C.amber} />
        <Text style={{ fontSize: 22, fontWeight: '800', color: C.ink }}>3 days</Text>
      </View>
    );
  if (kind === 'report')
    return (
      <View style={[styles.pv, { flexDirection: 'row', alignItems: 'flex-end', gap: 6, height: 46 }]}>
        {[0.4, 0.7, 0.55, 0.9, 0.3, 0, 0].map((h, i) => (
          <View key={i} style={{ width: 20, height: Math.max(5, 44 * h), borderRadius: 4, backgroundColor: h ? C.amber : C.line }} />
        ))}
      </View>
    );
  if (kind === 'quit')
    return (
      <View style={[styles.pv, { borderWidth: 1.5, borderColor: C.line, borderRadius: 12, paddingVertical: 8, paddingHorizontal: 12, alignSelf: 'flex-start' }]}>
        <Text style={{ fontWeight: '700', color: C.ink }}>Hold to quit</Text>
      </View>
    );
  if (kind === 'plus')
    return (
      <View style={[styles.pv, { alignSelf: 'flex-start', backgroundColor: C.ink, borderRadius: 99, paddingVertical: 4, paddingHorizontal: 12 }]}>
        <Text style={{ color: C.paper, fontWeight: '800', letterSpacing: 2, fontSize: 11 }}>PLUS</Text>
      </View>
    );
  return null;
}

const TRACK_W = 250, KNOB = 52, PAD = 4, MAX = TRACK_W - KNOB - PAD * 2;
const APPS = ['Instagram', 'TikTok', 'YouTube', 'Snapchat', 'X', 'Reddit'];
const TASKS = ['Studying', 'Homework', 'Work', 'Writing', 'Reading'];

function Slide({ glow, onDone, locked }) {
  const x = useRef(new Animated.Value(0)).current;
  const doneRef = useRef(onDone);
  doneRef.current = onDone;
  const pan = useRef(PanResponder.create({
    onStartShouldSetPanResponder: () => true,
    onPanResponderMove: (_, g) => x.setValue(Math.max(0, Math.min(MAX, g.dx))),
    onPanResponderRelease: (_, g) => {
      if (g.dx > MAX * 0.8) {
        Animated.timing(x, { toValue: MAX, duration: 120, useNativeDriver: false }).start(() => {
          doneRef.current();
          setTimeout(() => x.setValue(0), 900);
        });
      } else {
        Animated.spring(x, { toValue: 0, useNativeDriver: false, bounciness: 6 }).start();
      }
    },
  })).current;
  const fillW = x.interpolate({ inputRange: [0, MAX], outputRange: [KNOB + PAD * 2, TRACK_W] });
  const labelOp = x.interpolate({ inputRange: [0, MAX * 0.5], outputRange: [1, 0], extrapolate: 'clamp' });
  return (
    <View style={[styles.track, glow && styles.glow]}>
      <Animated.View style={[styles.fill, { width: fillW }]} />
      <Animated.Text style={[styles.slideText, { opacity: labelOp }]}>SLIDE TO LOCK IN</Animated.Text>
      <Animated.View {...pan.panHandlers} style={[styles.knob, { transform: [{ translateX: x }] }]}>
        <Ionicons name={locked ? 'checkmark' : 'arrow-forward'} size={24} color={C.ink} />
      </Animated.View>
    </View>
  );
}

function TourCard({ step, index, onNext, onSkip }) {
  const fade = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    fade.setValue(0);
    Animated.timing(fade, { toValue: 1, duration: 260, easing: Easing.out(Easing.cubic), useNativeDriver: true }).start();
  }, [step.id]);
  const down = step.pos === 'down';
  return (
    <Animated.View
      style={[
        styles.card,
        down ? { bottom: 14 } : { top: 92 },
        { opacity: fade, transform: [{ translateY: fade.interpolate({ inputRange: [0, 1], outputRange: [down ? 10 : -10, 0] }) }] },
      ]}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
        <Image source={brain} style={{ width: 54, height: 46 }} resizeMode="contain" />
        <Text style={styles.say}>{step.text}</Text>
      </View>
      {step.preview ? <View style={{ marginLeft: 64 }}><Preview kind={step.preview} /></View> : null}
      <View style={styles.foot}>
        <Text style={styles.count}>{index + 1}/{STEPS.length}</Text>
        <Pressable onPress={onSkip} hitSlop={10}><Text style={styles.skip}>Skip tour</Text></Pressable>
        {!step.act && (
          <Pressable onPress={onNext} style={styles.next}><Text style={styles.nextText}>Next</Text></Pressable>
        )}
      </View>
    </Animated.View>
  );
}

export default function App() {
  const [i, setI] = useState(0);
  const [done, setDone] = useState(false);
  const [task, setTask] = useState(null);
  const [picker, setPicker] = useState(false);
  const [appsOpen, setAppsOpen] = useState(false);
  const [mins, setMins] = useState(25);
  const [sheet, setSheet] = useState(null);
  const [goalH, setGoalH] = useState(5);
  const [lockedMode, setLockedMode] = useState(true);
  const [blocked, setBlocked] = useState(['TikTok', 'Instagram']);
  const step = STEPS[i];
  const g = done ? null : step.glow;
  const go = () => (i + 1 < STEPS.length ? setI(i + 1) : setDone(true));
  const act = (id) => {
    if (id === 'task') { setPicker(true); return; }
    if (id === 'shield') { setAppsOpen(true); return; }
    if (['mode', 'goal', 'partner', 'pc'].includes(id)) { setSheet(id); return; }
    if (!done && step.act && step.glow === id) go();
  };
  const pick = (t) => { setTask(t); setPicker(false); if (!done && step.id === 'task') go(); };
  const cardBelow = !done && step.pos === 'down' && !step.act;
  const sheetDone = () => { const id = sheet; setSheet(null); if (!done && step.id === id) go(); };
  const anySheet = picker || appsOpen || sheet;
  const toggle = (a) => setBlocked((b) => (b.includes(a) ? b.filter((x) => x !== a) : [...b, a]));
  const appsDone = () => { setAppsOpen(false); if (!done && step.id === 'apps') go(); };

  return (
    <SafeAreaView style={styles.root}>
      <StatusBar barStyle="dark-content" />
      <View style={styles.top}>
        <Text style={styles.logo}>Nogbox.</Text>
        <Pressable onPress={() => act('goal')}><Glow on={g === 'goal'} style={styles.ic}><Ionicons name="radio-button-on-outline" size={20} color={C.ink} /></Glow></Pressable>
        <Pressable onPress={() => act('partner')}><Glow on={g === 'partner'} style={styles.ic}><Ionicons name="people-outline" size={20} color={C.ink} /></Glow></Pressable>
        <Pressable onPress={() => act('shield')}>
          <Glow on={g === 'shield'} style={styles.ic}><Ionicons name="shield-outline" size={20} color={C.ink} /></Glow>
        </Pressable>
      </View>
      <Pressable onPress={() => act('pc')} style={{ alignSelf: 'flex-start' }}>
      <Glow on={g === 'pc'} style={styles.pcRow}>
        <Ionicons name="desktop-outline" size={16} color={C.ink} />
        <Text style={{ fontWeight: '600', fontSize: 13, color: C.ink }}>Connect a PC</Text>
      </Glow>
      </Pressable>

      <View style={styles.ringWrap}>
        <Image source={brain} style={{ width: 150, height: 128 }} resizeMode="contain" />
        <Text style={styles.time}>{mins}:00</Text>
        <Text style={styles.ready}>{done ? 'Locked in' : 'Ready'}</Text>
      </View>

      <View style={{ opacity: cardBelow ? 0 : 1 }}>
        <Pressable onPress={() => act('task')}>
          <Glow on={g === 'task'} style={styles.task}><Text style={{ color: task ? C.ink : C.soft, fontWeight: task ? '700' : '400' }}>{task ? `Working on ${task}` : 'What are you working on?'}</Text></Glow>
        </Pressable>
        <View style={styles.minsRow}>
          <Text style={{ fontWeight: '700', color: C.ink }}>Minutes</Text>
          <Pressable onPress={() => act('mode')}>
          <Glow on={g === 'mode'} style={styles.mode}>
            <Ionicons name="lock-open-outline" size={14} color={C.soft} />
            <Text style={{ color: C.soft, fontSize: 12 }}>Locked mode</Text>
            <Text style={styles.plusTag}>Plus</Text>
          </Glow>
          </Pressable>
        </View>
        <Glow on={g === 'seg'} style={styles.seg}>
          {[15, 25, 45, 60].map((m) => (
            <Pressable key={m} style={{ flex: 1 }} onPress={() => { setMins(m); act('seg'); }}>
              <View style={[styles.segItem, m === mins && { backgroundColor: C.ink, borderColor: C.ink }]}>
                <Text style={{ color: m === mins ? C.paper : C.ink, fontWeight: '600' }}>{m}</Text>
              </View>
            </Pressable>
          ))}
        </Glow>
        <View style={{ alignItems: 'center', marginTop: 14, marginBottom: 14 }}>
          <Slide glow={g === 'btn'} locked={done} onDone={() => act('btn')} />
        </View>
      </View>

      {picker && (
        <Pressable style={styles.scrim} onPress={() => setPicker(false)}>
          <Pressable style={styles.sheet}>
            <Text style={styles.sheetTitle}>What are you working on?</Text>
            {TASKS.map((t) => (
              <Pressable key={t} onPress={() => pick(t)} style={[styles.row, task === t && { backgroundColor: C.ink }]}>
                <Text style={{ fontSize: 16, fontWeight: '600', color: task === t ? C.paper : C.ink }}>{t}</Text>
              </Pressable>
            ))}
          </Pressable>
        </Pressable>
      )}

      {appsOpen && (
        <Pressable style={styles.scrim} onPress={appsDone}>
          <Pressable style={styles.sheet}>
            <Text style={styles.sheetTitle}>Which apps steal your time?</Text>
            {APPS.map((a) => {
              const on = blocked.includes(a);
              return (
                <Pressable key={a} onPress={() => toggle(a)} style={[styles.row, { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }]}>
                  <Text style={{ fontSize: 16, fontWeight: '600', color: C.ink }}>{a}</Text>
                  <View style={[styles.chk, on && { backgroundColor: C.ink, borderColor: C.ink }]}>
                    {on && <Ionicons name="checkmark" size={16} color={C.paper} />}
                  </View>
                </Pressable>
              );
            })}
            <Pressable onPress={appsDone} style={[styles.next, { marginTop: 6, height: 52 }]}>
              <Text style={styles.nextText}>{blocked.length ? 'Lock ' + blocked.length + ' apps' : 'Skip'}</Text>
            </Pressable>
          </Pressable>
        </Pressable>
      )}

      {sheet && (
        <Pressable style={styles.scrim} onPress={sheetDone}>
          <Pressable style={styles.sheet}>
            {sheet === 'mode' && (<>
              <Text style={styles.sheetTitle}>Locked mode</Text>
              <Text style={styles.body}>No quit button until the timer ends. For brave days.</Text>
              <Pressable onPress={() => setLockedMode(!lockedMode)} style={[styles.row, { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }]}>
                <Text style={{ fontSize: 16, fontWeight: '600', color: C.ink }}>Locked mode</Text>
                <View style={[styles.sw, lockedMode && { backgroundColor: C.ink }]}><View style={[styles.swDot, lockedMode && { alignSelf: 'flex-end' }]} /></View>
              </Pressable>
            </>)}
            {sheet === 'goal' && (<>
              <Text style={styles.sheetTitle}>Weekly goal</Text>
              <Text style={styles.body}>How many hours a week? I will keep count.</Text>
              <View style={{ flexDirection: 'row', gap: 8 }}>
                {[3, 5, 10, 15].map((h) => (
                  <Pressable key={h} onPress={() => setGoalH(h)} style={[styles.segItem, { height: 52 }, goalH === h && { backgroundColor: C.ink, borderColor: C.ink }]}>
                    <Text style={{ color: goalH === h ? C.paper : C.ink, fontWeight: '700' }}>{h}h</Text>
                  </Pressable>
                ))}
              </View>
            </>)}
            {sheet === 'partner' && (<>
              <Text style={styles.sheetTitle}>Bring a buddy</Text>
              <Text style={styles.body}>They see you are locked in. They can cheer, and let you out.</Text>
              <View style={[styles.row, { flexDirection: 'row', alignItems: 'center', gap: 10 }]}>
                <Ionicons name="paper-plane-outline" size={18} color={C.ink} />
                <Text style={{ fontSize: 16, fontWeight: '600', color: C.ink }}>Send an invite</Text>
              </View>
            </>)}
            {sheet === 'pc' && (<>
              <Text style={styles.sheetTitle}>Connect a PC</Text>
              <Text style={styles.body}>Open Nogbox on your PC. Type this code there.</Text>
              <View style={{ flexDirection: 'row', gap: 8, justifyContent: 'center' }}>
                {['4', '8', '2', '7'].map((d, k) => (
                  <View key={k} style={[styles.segItem, { flex: 0, width: 58, height: 64 }]}><Text style={{ fontSize: 28, fontWeight: '800', color: C.ink }}>{d}</Text></View>
                ))}
              </View>
            </>)}
            <Pressable onPress={sheetDone} style={[styles.next, { marginTop: 8, height: 52 }]}>
              <Text style={styles.nextText}>Done</Text>
            </Pressable>
          </Pressable>
        </Pressable>
      )}

      {!done && !anySheet && <TourCard key={step.id} step={step} index={i} onNext={go} onSkip={() => setDone(true)} />}
      {done && (
        <View style={[styles.card, { bottom: 14 }]}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
            <Image source={brain} style={{ width: 54, height: 46 }} resizeMode="contain" />
            <Text style={styles.say}>We're locked in. Go get it!</Text>
          </View>
          <View style={styles.foot}>
            <Text style={styles.count}>Tour done</Text>
            <Pressable onPress={() => { setI(0); setDone(false); }} style={styles.next}><Text style={styles.nextText}>Replay</Text></Pressable>
          </View>
        </View>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: C.paper, paddingHorizontal: 18, paddingTop: 8 },
  top: { flexDirection: 'row', alignItems: 'center', paddingTop: 8 },
  logo: { flex: 1, fontSize: 32, fontWeight: '800', letterSpacing: -1.8, color: C.ink },
  ic: { width: 44, height: 44, alignItems: 'center', justifyContent: 'center', borderRadius: 13 },
  pcRow: { flexDirection: 'row', alignItems: 'center', gap: 6, alignSelf: 'flex-start', paddingVertical: 8, paddingHorizontal: 10, borderRadius: 12 },
  glow: { borderWidth: 3, borderColor: C.amber, shadowColor: C.amber, shadowOpacity: 0.3, shadowRadius: 8, shadowOffset: { width: 0, height: 0 } },
  ringWrap: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingBottom: 20 },
  ring: { width: 210, height: 210, borderRadius: 105, borderWidth: 6, borderColor: C.line, alignItems: 'center', justifyContent: 'center' },
  time: { fontSize: 64, fontWeight: '800', letterSpacing: -3, color: C.ink, marginTop: 4 },
  ready: { color: C.soft, fontSize: 13, marginTop: 2 },
  task: { height: 44, borderRadius: 22, backgroundColor: '#fff', borderWidth: 1.5, borderColor: C.line, justifyContent: 'center', paddingHorizontal: 16 },
  minsRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: 14, marginBottom: 8 },
  mode: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingVertical: 5, paddingHorizontal: 8, borderRadius: 12 },
  plusTag: { fontSize: 10, color: C.soft, borderWidth: 1, borderColor: C.line, borderRadius: 5, paddingHorizontal: 4 },
  seg: { flexDirection: 'row', gap: 8, borderRadius: 16 },
  segItem: { flex: 1, height: 46, borderRadius: 14, borderWidth: 1.5, borderColor: C.line, alignItems: 'center', justifyContent: 'center' },
  track: { width: TRACK_W, height: KNOB + PAD * 2, borderRadius: (KNOB + PAD * 2) / 2, backgroundColor: C.ink, justifyContent: 'center', overflow: 'hidden' },
  fill: { position: 'absolute', left: 0, top: 0, bottom: 0, backgroundColor: '#3A352F', borderRadius: 30 },
  slideText: { color: C.paper, fontWeight: '800', letterSpacing: 2, fontSize: 13, textAlign: 'center', paddingLeft: KNOB },
  knob: { position: 'absolute', left: PAD, width: KNOB, height: KNOB, borderRadius: KNOB / 2, backgroundColor: C.paper, alignItems: 'center', justifyContent: 'center' },
  scrim: { position: 'absolute', top: 0, bottom: 0, left: 0, right: 0, backgroundColor: '#17151355', justifyContent: 'flex-end' },
  sheet: { backgroundColor: C.paper, borderTopLeftRadius: 26, borderTopRightRadius: 26, padding: 18, paddingBottom: 34, gap: 8 },
  sheetTitle: { fontSize: 20, fontWeight: '800', color: C.ink, marginBottom: 6 },
  chk: { width: 24, height: 24, borderRadius: 7, borderWidth: 1.5, borderColor: C.soft, alignItems: 'center', justifyContent: 'center' },
  body: { fontSize: 14, color: C.soft, lineHeight: 20, marginBottom: 6 },
  sw: { width: 48, height: 28, borderRadius: 14, backgroundColor: C.line, padding: 3 },
  swDot: { width: 22, height: 22, borderRadius: 11, backgroundColor: C.paper },
  row: { height: 52, borderRadius: 16, backgroundColor: C.inset, justifyContent: 'center', paddingHorizontal: 16 },
  btn: { marginTop: 14, marginBottom: 12, height: 60, borderRadius: 17, backgroundColor: C.ink, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20 },
  btnText: { color: C.paper, fontSize: 18, fontWeight: '800' },
  card: { position: 'absolute', left: 14, right: 14, backgroundColor: C.paper, borderRadius: 22, borderWidth: 1.5, borderColor: C.line, padding: 12, shadowColor: '#000', shadowOpacity: 0.14, shadowRadius: 16, shadowOffset: { width: 0, height: 6 }, elevation: 8 },
  say: { flex: 1, fontSize: 15, fontWeight: '700', lineHeight: 20, color: C.ink },
  pv: { marginTop: 10 },
  foot: { flexDirection: 'row', alignItems: 'center', gap: 14, marginTop: 8, marginLeft: 64 },
  count: { flex: 1, fontSize: 12, color: C.soft },
  skip: { fontSize: 12, color: C.soft, paddingVertical: 10 },
  next: { backgroundColor: C.ink, borderRadius: 22, paddingHorizontal: 20, height: 44, alignItems: 'center', justifyContent: 'center' },
  nextText: { color: C.paper, fontWeight: '800', fontSize: 14 },
});
