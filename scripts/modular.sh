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

curl -ssL https://magic.modular.com/fac081a7-8e92-4dde-87c8-a01e96d0de1d | bash
BASHRC=$( [ -f "$HOME/.bash_profile" ] && echo "$HOME/.bash_profile" || echo "$HOME/.bashrc" )
echo 'eval "$(magic completion --shell bash)"' >> "$BASHRC"
source "$BASHRC"

# Create project to install the required global dependencies
magic init my-mojo-project --format mojoproject
