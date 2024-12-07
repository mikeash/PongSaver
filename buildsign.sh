#! /bin/bash

. .env

# Run the build
xcodebuild

# Sign the build
codesign -f -o runtime --timestamp --sign "$KEYCHAIN_CERTNAME" build/Release/PongSaver.saver

# Verify the signature
codesign -vvv --deep --strict "build/Release/PongSaver.saver"

# Zip the build for notarization
(cd build/Release && zip -r "../PongSaver.saver.zip" "PongSaver.saver" && echo "First zip Successful" || echo "Zip FAILED")

# Submit to apple for notarization
xcrun notarytool submit "build/PongSaver.saver.zip" --team-id "SG6DU88C24" --apple-id "$APPLE_ID" --password "$APP_SPECIFIC_PASSWORD" --wait

# # For debugging failed notarization
# # xcrun notarytool log --team-id $TEAM_ID --apple-id $APPLE_ID --password $APP_SPECIFIC_PASSWORD d5fasdfd-6db9-4e0c-b973-dff3ddfs2b57

# Attach the notarization ticket to the build files
xcrun stapler staple "build/Release/PongSaver.saver"

# Re-zip the build for distribution
(cd build/Release && zip -r "../PongSaver.saver.zip" "PongSaver.saver" && echo "Final zip Successful" || echo "Zip FAILED")

# Clean up, delete all files except the released build zip
find build -type f ! -name "PongSaver.saver.zip" -delete
find build -type d -empty -delete