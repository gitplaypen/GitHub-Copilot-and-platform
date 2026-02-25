#!/bin/bash
set -e

# Write the ENV secret to a .env file inside the container at runtime.
# ENV_SECRET is injected at runtime by the container host - never at build time.
if [ -n "$ENV_SECRET" ]; then
  echo "$ENV_SECRET" > /app/.env
  echo ".env file created from ENV_SECRET."
else
  echo "Warning: ENV_SECRET is not set. No .env file will be created."
fi

# Start the application
exec dotnet ZavaStorefront.dll
