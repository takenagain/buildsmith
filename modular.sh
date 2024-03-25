curl -s https://get.modular.com | sh -

modular auth 

modular install mojo
modular update mojo

modular install max 

MAX_PATH=$(modular config max.path) \
  && python3 -m pip install --find-links $MAX_PATH/wheels max-engine
  
 MAX_PATH=$(modular config max.path) \
  && BASHRC=$( [ -f "$HOME/.bash_profile" ] && echo "$HOME/.bash_profile" || echo "$HOME/.bashrc" ) \
  && echo 'export MODULAR_HOME="'$HOME'/.modular"' >> "$BASHRC" \
  && echo 'export PATH="'$MAX_PATH'/bin:$PATH"' >> "$BASHRC" \
  && source "$BASHRC"
