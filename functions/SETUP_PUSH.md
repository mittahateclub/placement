# WhatsApp-style push (FCM) — setup

The app code and the Cloud Functions are done. Three steps remain that need your
Firebase account (I can't do them from here).

## 1. Register the Android app + add `google-services.json`
FCM on Android needs a real Android app registered in the Firebase project
(`uniship-4c1a1`) — right now the app only has web config.

1. Firebase console → Project settings → **Your apps** → **Add app** → Android.
2. Package name: `com.uniship.uniship_app`.
3. Download **`google-services.json`** and put it at:
   `android/app/google-services.json`.

That's all the app side needs — the gradle plugin is already wired in
`android/settings.gradle.kts` and `android/app/build.gradle.kts`.

> iOS (optional, later): also needs an APNs auth key uploaded under
> Cloud Messaging, plus the Push Notifications capability in Xcode.

## 2. Deploy the Cloud Functions
From the project root:

```bash
cd functions && npm install && cd ..
firebase deploy --only functions
```

This deploys four triggers: `onEventCreated`, `onInternshipCreated`,
`onPracticeCreated`, `onTestApproved`.

> Cloud Functions require the project to be on the **Blaze** (pay-as-you-go)
> plan. The free monthly allowance covers this kind of low-volume usage.

## 3. Test it
1. Run the app, sign in as a student → a token is written to
   `users/{uid}.fcmTokens`.
2. Fully close the app.
3. Post a new internship/event for that student's university (admin web/app).
4. The phone should get a system notification within seconds.

## How targeting works
- **Internships / practice / tests**: sent to students whose `universityId`
  matches the document. Tests fire when `approved` flips to `true`.
- **Events**: sent to students matching `targetBranches` / `minGpa`
  (mirrors `eventTargetsStudent` in the app).
- Dead tokens are pruned automatically when a send fails.
