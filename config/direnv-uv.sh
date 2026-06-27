# layout_uv — direnv + uv integration
# Install: copy to ~/.config/direnv/lib/uv.sh
# Use in .envrc: `layout uv`

layout_uv() {
  # Create .venv if it doesn't exist
  if [ ! -d ".venv" ]; then
    uv venv --quiet
  fi

  export VIRTUAL_ENV="$(pwd)/.venv"

  # Add .venv/bin to PATH
  PATH_add ".venv/bin"

  # Inform user
  if [ -n "${DIRENV_LOG_FORMAT:-}" ]; then
    watch_file .venv/pyvenv.cfg
  fi
}
