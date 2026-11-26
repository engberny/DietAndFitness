# Putting the app on TestFlight (no Mac needed)

GitHub builds the app on a Mac in the cloud, signs it with your Apple Developer account and uploads it
to TestFlight. You do the one-time setup below (about 15 minutes), then press a button for each new build.

Never paste the API key into a chat or commit it to the repo. It only goes into GitHub secrets.

## 1. Register the bundle ID

1. Go to [developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers/list) and press **+**.
2. Choose **App IDs**, then **App**, then Continue.
3. Description: `Diet Log`. Bundle ID: **Explicit**, `com.engberny.DietAndFitness`.
4. Leave the capabilities alone and press Continue, then Register.

## 2. Create the app in App Store Connect

1. Go to [appstoreconnect.apple.com/apps](https://appstoreconnect.apple.com/apps), press **+**, then **New App**.
2. Platform: **iOS**. Name: anything not already taken on the App Store (for example `Diet Log Lucas`).
   The name under the icon on your phone stays "Diet Log".
3. Primary language: English (U.S.). Bundle ID: pick `com.engberny.DietAndFitness`.
4. SKU: anything, for example `dietlog`. User access: Full Access. Press Create.

## 3. Create an App Store Connect API key

1. In App Store Connect go to **Users and Access**, then the **Integrations** tab, then **App Store Connect API**
   ([direct link](https://appstoreconnect.apple.com/access/integrations/api)). If asked, request access first.
2. Under **Team Keys** press **+** (or "Generate API Key").
3. Name: `GitHub`. Access: **Admin** (needed so the build can create its own signing certificate).
4. Press Generate, then **Download** the `.p8` file. Apple only lets you download it once, so keep it safe.
5. Note the **Key ID** next to the key and the **Issuer ID** shown above the list.

## 4. Find your Team ID

Go to [developer.apple.com/account](https://developer.apple.com/account), scroll to **Membership details**,
and note the **Team ID** (10 letters and numbers).

## 5. Add four secrets to GitHub

Go to [the repo's Actions secrets](https://github.com/engberny/DietAndFitness/settings/secrets/actions)
(Settings > Secrets and variables > Actions) and press **New repository secret** for each:

| Name | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Your Team ID from step 4 |
| `ASC_KEY_ID` | The Key ID from step 3 |
| `ASC_ISSUER_ID` | The Issuer ID from step 3 |
| `ASC_PRIVATE_KEY` | The whole text of the `.p8` file, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines. Open it with Notepad or any text editor and copy everything. |

## 6. Build and upload

1. Open the repo's **Actions** tab, choose **TestFlight** on the left, press **Run workflow**, then the green Run workflow button.
2. It takes about 10 to 15 minutes. A green check means the upload worked.
3. In App Store Connect, open your app's **TestFlight** tab. The build shows "Processing" for a few minutes, then appears.
4. Under **Internal Testing**, press **+** to create a group, add yourself as a tester, and add the build to it.
5. Install the **TestFlight** app on your iPhone, sign in with the same Apple ID, and install Diet Log from there.

For each new version, just run the workflow again. Build numbers go up automatically.
