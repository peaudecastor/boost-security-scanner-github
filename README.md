# Boost Security Scanner Action

Executes the Boost Security Scanner cli tool to scan repositories for
vulnerabilities and uploads results to the Boost API. This plugin
runs as a post-command hook.

## Example

Add the following to your `.github/workflows/boostsecurity.yml`:

```yml
on:
  push:
    branches:
      - master

  pull_request:
    branches:
      - master
    types:
      - opened
      - synchronize

jobs:
  scan_job:
    name: Boost Security Scanner
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Login to ECR
        uses: docker/login-action@v1
        with:
          registry: 706352083976.dkr.ecr.us-east-2.amazonaws.com
          username: ${{ secrets.AWS_ACCESS_KEY_ID }}
          password: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      - name: Scan Repository
        uses: peaudecastor/boost-security-scanner-github@2.0
        with:
          api_token: ${{ secrets.BOOST_API_TOKEN }}
```

## Configuration

### `additional_args` (Optional, str)

Additional CLI args to pass to the `boost` cli.

### `api_endpoint` (Optional, string)

Overrides the API endpoint url

### `api_token` (Required, string)

The Boost Security API token secret.

**NOTE**: We recommend you not put the API token directly in your pipeline.yml
file. Instead, it should be exposed via a **secret**.

### `scanner_command` (Optional, string)

The Boost CLI command to run.
This defaults to `scan ci`.

### `scanner_image` (Optional, string)

Overrides the docker image url to load when performing scans

### `scanner_version` (Optional, string)

Overrides the docker image tag to load when performing scans. If undefined,
this will default to pulling the latest image from the current release channel.


