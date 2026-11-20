FROM debian:trixie

RUN printf '%s\n' \
    'plugins=(' \
    '  git' \
    '  # keep the rest of this file' \
    '  docker' \
    ')' \
    'ZSH_THEME="robbyrussell"' \
    > /root/.zshrc
