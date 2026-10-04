# PriceHUD Play Store release checklist

## Before the first upload

1. Deploy `backend/` to a public HTTPS provider with PostgreSQL and create
   device activation codes as described in `backend/README.md`.
2. Run the MT5 agent from a Windows PC or VPS that stays online. Do not expose
   MetaTrader or a home-network port to the internet.
3. Replace the privacy-policy draft at `https://YOUR_API/privacy` with the
   publisher's legal name, contact email, website, retention period, and a
   support contact. Keep that page public and use its HTTPS URL in Play Console.
4. Create a dedicated upload keystore. Keep its passwords in a password
   manager and back up the keystore securely:

   ```powershell
   keytool -genkeypair -v -keystore upload-keystore.jks -alias upload `
     -keyalg RSA -keysize 4096 -validity 10000
   Copy-Item android\key.properties.example android\key.properties
   ```

   Fill `android/key.properties` with the actual keystore location and secrets.
   The app now rejects release builds that would use the debug signing key.
5. Build the Android App Bundle:

   ```powershell
   . .\scripts\toolchain_env.ps1
   flutter analyze
   flutter test
   flutter build appbundle --release
   ```

   Upload `build/app/outputs/bundle/release/app-release.aab`, not an APK.

## Play Console setup

1. Create the app, set the correct package id and store listing, then enroll in
   Play App Signing.
2. Complete the Data safety form based on the deployed backend and privacy
   policy. PriceHUD transmits an app-generated device authorization token and
   technical request data to supply live quotes; it does not need brokerage
   passwords or trading permissions.
3. Complete the App content questionnaires, content rating, target audience,
   app access instructions, support email, and privacy policy URL.
4. Run an internal test first. For new personal developer accounts, plan the
   required closed test before requesting production access.
5. Test an installed release AAB build on a physical Android phone: activation,
   live MT5 quote, overlay while another app is foreground, drag-to-close,
   disconnect, and network-loss behavior.

## Never put these in the app or repository

- MT5 login or trading password
- `AGENT_API_KEY`, `ADMIN_API_KEY`, or `TOKEN_PEPPER`
- The Android upload keystore or its passwords
- A cloud database password
