# Script to upload and run seeds on the Nerves device
# Usage: ./run_seed.sh [device_address]
# Example: ./run_seed.sh nerves.local

DEVICE=${1:-nerves.local}
SEED_FILE="priv/repo/seeds.exs"
REMOTE_PATH="/data/seeds.exs"

echo "📦 Uploading seed file to $DEVICE..."
scp "$SEED_FILE" "$DEVICE:$REMOTE_PATH" 2>&1

echo "🔍 Verifying file was uploaded..."
RESULT=$(ssh "$DEVICE" "File.exists?('$REMOTE_PATH')" 2>&1)

if [[ "$RESULT" != *"true"* ]]; then
    echo "❌ Failed to upload seed file (file not found on device)"
    exit 1
fi

echo "✅ Seed file uploaded successfully"
echo "🌱 Running seed file on device..."

OUTPUT=$(ssh "$DEVICE" "Code.eval_file(\"$REMOTE_PATH\")" 2>&1)
EXIT_CODE=$?

echo "$OUTPUT"

if [ $EXIT_CODE -eq 0 ] && echo "$OUTPUT" | grep -q "Test scenarios covered:"; then
    echo ""
    echo "✅ Seed executed successfully!"
else
    echo ""
    echo "❌ Failed to execute seed"
    exit 1
fi
