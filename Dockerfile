FROM node:20-alpine
WORKDIR /app
COPY install.sh ./
COPY my-config/ ./my-config/
COPY skills/ ./skills/
COPY NOTICE.md ./
COPY README.md ./
COPY CLAUDE.md ./
RUN chmod +x install.sh

# Dry-run validation
RUN bash install.sh --dry-run 2>&1 || true

CMD ["bash"]
