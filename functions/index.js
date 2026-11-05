const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function notify(userId, title, body) {
  const u = await db.doc(`users/${userId}`).get();
  const token = u.exists && u.data().fcmToken;
  if (token) await admin.messaging().send({ token, notification: { title, body } }).catch(() => {});
}

// Push notification + reward points when a pickup changes status.
exports.onRequestUpdate = functions.firestore
  .document('requests/{id}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.status === after.status) return;
    await notify(after.userId, 'Pickup update', `Your pickup is now: ${after.status.replace('_', ' ')}`);
    if (after.status === 'completed') {
      const pts = after.wasteType === 'Recyclable' ? 20 : 5;
      await db.doc(`users/${after.userId}`).update({ points: admin.firestore.FieldValue.increment(pts) });
    }
  });

// Push notification when a complaint is resolved.
exports.onComplaintUpdate = functions.firestore
  .document('complaints/{id}')
  .onUpdate(async (change) => {
    const b = change.before.data();
    const a = change.after.data();
    if (b.status !== a.status) {
      await notify(a.userId, 'Complaint update', `Your complaint is now: ${a.status}`);
    }
  });

// Admin-only: order each driver's stops for a day using the Google Routes API.
exports.optimizeRoutes = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  const me = await db.doc(`users/${context.auth.uid}`).get();
  if (!me.exists || me.data().role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Admins only');
  }
  const day = data.date ? new Date(data.date) : new Date();
  const key = (d) => `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
  const target = key(day);

  const snap = await db.collection('requests').where('status', '==', 'scheduled').get();
  const byDriver = {};
  snap.forEach((doc) => {
    const r = doc.data();
    if (!r.driverId || !r.scheduledDate || key(r.scheduledDate.toDate()) !== target) return;
    (byDriver[r.driverId] = byDriver[r.driverId] || []).push({ id: doc.id, loc: r.location });
  });

  const depot = {
    latitude: parseFloat(process.env.DEPOT_LAT || '30.9010'),
    longitude: parseFloat(process.env.DEPOT_LNG || '75.8573'),
  };
  let routes = 0;
  for (const [driverId, stops] of Object.entries(byDriver)) {
    let order = stops.map((_, i) => i);
    if (stops.length > 1) {
      const wp = (l) => ({ location: { latLng: { latitude: l.latitude, longitude: l.longitude } } });
      const res = await fetch('https://routes.googleapis.com/directions/v2:computeRoutes', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': process.env.MAPS_KEY,
          'X-Goog-FieldMask': 'routes.optimizedIntermediateWaypointIndex',
        },
        body: JSON.stringify({
          origin: wp(depot),
          destination: wp(depot),
          intermediates: stops.map((s) => wp(s.loc)),
          travelMode: 'DRIVE',
          optimizeWaypointOrder: true,
        }),
      });
      const json = await res.json();
      const idx = json.routes && json.routes[0] && json.routes[0].optimizedIntermediateWaypointIndex;
      if (idx) order = idx;
      else console.error('Routes API error', JSON.stringify(json));
    }
    const batch = db.batch();
    order.forEach((stopIdx, position) => {
      batch.update(db.doc(`requests/${stops[stopIdx].id}`), { stopOrder: position });
    });
    batch.set(db.collection('routes').doc(`${driverId}_${target}`), {
      driverId, date: day.toISOString(), orderedRequestIds: order.map((i) => stops[i].id),
    });
    await batch.commit();
    routes++;
  }
  return { routes };
});
