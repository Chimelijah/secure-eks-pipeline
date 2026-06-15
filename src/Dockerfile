# SECURE: Minimal base image reduces attack surface
FROM python:3.9-slim

# SECURE: Create a non-root user and group
RUN groupadd -r appgroup && useradd -r -g appgroup appuser
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
# SECURE: Hand over ownership and switch to non-root user
RUN chown -R appuser:appgroup /app
USER appuser
EXPOSE 8080
CMD ["python", "app.py"]