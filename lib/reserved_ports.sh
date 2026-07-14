_reserved_ports_registry() {
  printf '%s\n' "${DIRENV_PORT_REGISTRY:-${XDG_STATE_HOME:-$HOME/.local/state}/direnv/reserved-ports}"
}

_reserved_ports_root() {
  cd -- "${DIRENV_DIR:-$PWD}" 2>/dev/null && pwd -P
}

_reserved_ports_read() {
  [[ -f "$1" ]] || return 1
  IFS= read -r REPLY <"$1"
}

_reserved_ports_valid_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && (($1 >= 1024 && $1 <= 65535))
}

_reserved_ports_new_id() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen
  else
    printf 'r%s-%s-%s-%s\n' "$(date +%s%N)" "$$" "$RANDOM" "$RANDOM"
  fi
}

_reserved_ports_claim_global() {
  local registry="$1"
  local reservation_id="$2"
  local port="$3"
  local port_file="$registry/by-port/$port"

  mkdir -p -- "$registry/by-port" "$registry/by-id" || return 1

  if (set -C; printf '%s\n' "$reservation_id" >"$port_file") 2>/dev/null; then
    printf '%s\n' "$port" >"$registry/by-id/$reservation_id" || {
      rm -f -- "$port_file" "$registry/by-id/$reservation_id"
      return 1
    }
    return 0
  fi

  _reserved_ports_read "$port_file" || return 2
  [[ "$REPLY" == "$reservation_id" ]] || return 2

  printf '%s\n' "$port" >"$registry/by-id/$reservation_id"
}

is_port_reserved() {
  local port="${1:?usage: is_port_reserved port}"

  _reserved_ports_valid_port "$port" &&
    [[ -f "$(_reserved_ports_registry)/by-port/$port" ]]
}

reserved_port_owner() {
  local port="${1:?usage: reserved_port_owner port}"

  _reserved_ports_valid_port "$port" || return 1
  _reserved_ports_read "$(_reserved_ports_registry)/by-port/$port" || return 1

  printf 'port=%s\nreservation_id=%s\n' "$port" "$REPLY"
}

reserve_port_for() {
  local marker="${1:?usage: reserve_port_for marker [min_port] [max_port]}"
  local min_port="${2:-61000}"
  local max_port="${3:-64999}"
  local root registry local_dir marker_dir reservation_id port status

  case "$marker" in
    "" | *[!a-zA-Z0-9_.-]*)
      log_error "invalid port marker: $marker"
      return 1
      ;;
  esac

  if [[ ! "$min_port:$max_port" =~ ^[0-9]+:[0-9]+$ ]] ||
    ((min_port < 1024 || max_port > 65535 || min_port > max_port)); then
    log_error "invalid port range: $min_port-$max_port"
    return 1
  fi

  root="$(_reserved_ports_root)" || {
    log_error "project directory unavailable"
    return 1
  }

  registry="$(_reserved_ports_registry)"
  local_dir="$root/.direnv/reserved-ports"
  marker_dir="$local_dir/$marker"

  mkdir -p -- "$marker_dir" || {
    log_error "port registry unavailable"
    return 1
  }

  if _reserved_ports_read "$marker_dir/reservation_id"; then
    reservation_id="$REPLY"
  else
    reservation_id="$(_reserved_ports_new_id)" || {
      log_error "failed to create port reservation id: $marker"
      return 1
    }

    printf '%s\n' "$reservation_id" >"$marker_dir/reservation_id" || {
      log_error "failed to write port reservation id: $marker"
      return 1
    }
  fi

  if _reserved_ports_read "$marker_dir/port"; then
    port="$REPLY"

    if _reserved_ports_valid_port "$port"; then
      _reserved_ports_claim_global "$registry" "$reservation_id" "$port"
      status=$?

      if ((status == 0)); then
        log_status "port reserved: $marker -> $port"
        printf '%s\n' "$port"
        return 0
      fi
    fi
  fi

  if _reserved_ports_read "$registry/by-id/$reservation_id"; then
    port="$REPLY"

    if _reserved_ports_valid_port "$port" &&
      _reserved_ports_read "$registry/by-port/$port" &&
      [[ "$REPLY" == "$reservation_id" ]]; then
      printf '%s\n' "$port" >"$marker_dir/port" || {
        log_error "failed to write local port reservation: $port"
        return 1
      }

      log_status "port reserved: $marker -> $port"
      printf '%s\n' "$port"
      return 0
    fi
  fi

  for ((port = min_port; port <= max_port; port++)); do
    _reserved_ports_claim_global "$registry" "$reservation_id" "$port"
    status=$?

    if ((status == 0)); then
      printf '%s\n' "$port" >"$marker_dir/port" || {
        rm -f -- "$registry/by-id/$reservation_id" "$registry/by-port/$port"
        log_error "failed to write local port reservation: $port"
        return 1
      }

      log_status "port reserved: $marker -> $port"
      printf '%s\n' "$port"
      return 0
    fi

    if ((status == 1)); then
      log_error "failed to write global port reservation: $port"
      return 1
    fi
  done

  log_error "no free port in range: $min_port-$max_port"
  return 1
}

reserve_port() {
  reserve_port_for "$@"
}
