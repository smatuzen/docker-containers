#!/bin/sh -e

# If command is provided, execute it.
if [ "$#" -gt 0 ]; then
  exec "$@"
fi

# Legacy compatible:
if [ -z "$NGROK_PORT" ]; then
  if [ -n "$HTTPS_PORT" ]; then
    NGROK_PORT="$HTTPS_PORT"
  elif [ -n "$HTTP_PORT" ]; then
    NGROK_PORT="$HTTP_PORT"
  elif [ -n "$APP_PORT" ]; then
    NGROK_PORT="$APP_PORT"
  fi
fi

# Build args safely using positional parameters.
set -- ngrok

# Set the protocol and default port.
case "$NGROK_PROTOCOL" in
  TCP)
    set -- "$@" tcp
    ;;
  TLS)
    set -- "$@" tls
    NGROK_PORT="${NGROK_PORT:-443}"
    ;;
  *)
    set -- "$@" http
    NGROK_PORT="${NGROK_PORT:-80}"
    ;;
esac

# Set the TLS binding flag.
if [ -n "$NGROK_BINDTLS" ]; then
  set -- "$@" "-bind-tls=$NGROK_BINDTLS"
fi

# Set the authorization token (write to config).
if [ -n "$NGROK_AUTH" ]; then
  mkdir -p "$HOME/.ngrok2"
  printf '\nauthtoken: %s\n' "$NGROK_AUTH" >> "$HOME/.ngrok2/ngrok.yml"
fi

# Set the subdomain or hostname (requires auth).
if [ -n "$NGROK_HOSTNAME" ] && [ -n "$NGROK_AUTH" ]; then
  set -- "$@" "-hostname=$NGROK_HOSTNAME"
elif [ -n "$NGROK_SUBDOMAIN" ] && [ -n "$NGROK_AUTH" ]; then
  set -- "$@" "-subdomain=$NGROK_SUBDOMAIN"
elif [ -n "$NGROK_HOSTNAME" ] || [ -n "$NGROK_SUBDOMAIN" ]; then
  if [ -z "$NGROK_AUTH" ]; then
    echo "You must specify an authentication token after registering at https://ngrok.com to use custom domains."
    exit 1
  fi
fi

# Set the reserved remote address (requires auth).
if [ -n "$NGROK_REMOTE_ADDR" ]; then
  if [ -z "$NGROK_AUTH" ]; then
    echo "You must specify an authentication token after registering at https://ngrok.com to use reserved IP addresses."
    exit 1
  fi
  set -- "$@" "-remote-addr=$NGROK_REMOTE_ADDR"
fi

# Set a custom region.
if [ -n "$NGROK_REGION" ]; then
  set -- "$@" "-region=$NGROK_REGION"
fi

# Set a custom Host header.
if [ -n "$NGROK_HEADER" ]; then
  set -- "$@" "-host-header=$NGROK_HEADER"
fi

# Set HTTP basic auth (requires auth token present).
if [ -n "$NGROK_USERNAME" ] && [ -n "$NGROK_PASSWORD" ] && [ -n "$NGROK_AUTH" ]; then
  set -- "$@" "-auth=$NGROK_USERNAME:$NGROK_PASSWORD"
elif [ -n "$NGROK_USERNAME" ] || [ -n "$NGROK_PASSWORD" ]; then
  if [ -z "$NGROK_AUTH" ]; then
    echo "You must specify a username, password, and Ngrok authentication token to use custom HTTP authentication."
    echo "Sign up for an authentication token at https://ngrok.com"
    exit 1
  fi
fi

# Enable debug logging to stdout.
if [ -n "$NGROK_DEBUG" ]; then
  set -- "$@" -log stdout
fi

# Ensure port is set.
if [ -z "$NGROK_PORT" ]; then
  echo "You must specify an NGROK_PORT to expose."
  exit 1
fi

# Final target (optionally with a look domain), strip any tcp:// prefix.
if [ -n "$NGROK_LOOK_DOMAIN" ]; then
  target="$NGROK_LOOK_DOMAIN:$NGROK_PORT"
else
  target="$NGROK_PORT"
fi
target=${target#tcp://}

set -- "$@" "$target"

exec "$@"
