data "external" "generate-secret" {
  program = ["python3", "scripts/generate-secret.py"]
  query = {
    length  = 16
    symbols = true
  }
}
