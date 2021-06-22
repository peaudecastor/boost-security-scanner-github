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
        uses: peaudecastor/boost-security-scanner-github@v2.0
        with:
          api_token: ${{ secrets.BOOST_API_TOKEN }}
```

## Configuration

### `action` (Required, string)

The action to perform by the plugin:
- `scan`: Executes the BoostSecurity native scanner with a number of plugins
- `exec`: Executes a custom command which outputs Sarif to stdout.
- `complete`: Completes a Scan when in `partial` mode.

### `additional_args` (Optional, str)

Additional CLI args to pass to the `boost` cli.

Optional arguments:
- `--partial`: Enables partial mode, allowing you to combine the results of multiple scans.

### `api_endpoint` (Optional, string)

Overrides the API endpoint url

### `api_token` (Required, string)

The Boost Security API token secret.

**NOTE**: We recommend you not put the API token directly in your pipeline.yml
file. Instead, it should be exposed via a **secret**.

### `cli_version` (Optional, string)

Overrides the cli version to download when performing scans. If undefined,
this will default to pulling "2.0".

### `exec_command` (Optional, string)

A custom command to run in by the `exec` action. This should be a command which executes a custom scanner and outputs only a Sarif document to stdout.

The value may additionally contain the `%CWD%` placeholder which will be replaced by the correct working directory during evaluation. The is especially useful when combined with volume mounts in a docker command.

### `scanner_image` (Optional, string)

Overrides the docker image url to load when performing scans

### `scanner_version` (Optional, string)

Overrides the docker image tag to load when performing scans. If undefined,
this will default to pulling the latest image from the current release channel.


