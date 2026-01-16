# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`gsuite_api` is a Ruby gem that provides a simplified interface to Google's v4 APIs, specifically for Google Sheets and Google Drive operations. It wraps the official Google API client libraries with a more ergonomic Ruby interface.

## Development Commands

### Setup
```bash
bin/setup          # Install dependencies
bin/console        # Interactive console for experimentation
```

### Testing
```bash
rake spec          # Run all tests
bundle exec rspec  # Run tests via bundler
```

### Installation & Release
```bash
bundle exec rake install   # Install gem locally
bundle exec rake release   # Tag version, push commits/tags, push to rubygems
```

## Authentication

The gem uses Google service account authentication with user impersonation. Three environment variables control authentication:

- `GSUITE_USER` - User email to impersonate when using service account
- `GOOGLE_APPLICATION_CREDENTIALS` - Path to credentials JSON file
- `GOOGLE_CREDENTIALS_BASE64` - Base64-encoded credentials (will be written to path specified in GOOGLE_APPLICATION_CREDENTIALS if file doesn't exist)

The `GSuiteAPI::DumpCredentials.dump` helper can decode base64 credentials and write them to disk.

Authentication is initialized via `GSuiteAPI.auth_client` which:
1. Uses `Google::Auth.get_application_default` with drive and spreadsheets scopes
2. Duplicates the authorization and sets `.sub = ENV["GSUITE_USER"]` for impersonation
3. Fetches and caches the access token

## Architecture

### Module Structure

```
GSuiteAPI (lib/gsuite_api.rb)
├── Sheets (lib/gsuite_api/sheets.rb)
│   ├── Spreadsheet (lib/gsuite_api/sheets/spreadsheet.rb)
│   └── Sheet (lib/gsuite_api/sheets/sheet.rb)
├── Drive (lib/gsuite_api/drive.rb)
│   └── File (lib/gsuite_api/drive/file.rb)
└── DumpCredentials (lib/gsuite_api/dump_credentials.rb)
```

### Sheets API

**Access patterns:**
```ruby
# Get spreadsheet by ID
GSuiteAPI::Sheets.by_id(spreadsheet_id)

# Get specific sheet within spreadsheet
GSuiteAPI::Sheets.sheet(id: spreadsheet_id, name: "Sheet1")
```

**Spreadsheet class** (`lib/gsuite_api/sheets/spreadsheet.rb`):
- Represents a Google Sheets file (not individual tabs)
- Access sheets via `spreadsheet["Sheet Name"]` which returns a Sheet object
- Methods: `sheets`, `title`, `delete(sheet_ids:)`, `duplicate(from:, to:)`, `refresh`

**Sheet class** (`lib/gsuite_api/sheets/sheet.rb`):
- Represents an individual tab/sheet within a spreadsheet
- Delegates `id`, `service` to parent spreadsheet
- Key methods:
  - `get(range:)` - Read values from range
  - `set(range:, values:, value_input_option:)` - Write values to range
  - `clear(range:)` - Clear range
  - `upsert_table(values:, value_input_option:, extra_a1_note:)` - Update headers and replace table data
  - `replace_table(values:, value_input_option:)` - Clear and replace all data rows (A2 onwards)
  - `insert_rows(number, start_index:)`, `delete_rows(number, start_index:)`
  - `add_a1_note(note:)` - Add note to cell A1
- Important: Sheet names with special characters are wrapped in single quotes in A1 notation via `range_with_name(range)` (e.g., `'Sheet Name'!A1:B2`)
- `BATCH_SIZE = 10000` - Batch size for writing large datasets
- `table_row_count` - Count of non-empty rows based on column A
- Important implementation detail: `replace_table` adds a 1-second sleep after row insertion and sleeps for the duration of each batch write to allow Google's backend to settle

### Drive API

**Access pattern:**
```ruby
GSuiteAPI::Drive.file_by_id(file_id)
```

**File class** (`lib/gsuite_api/drive/file.rb`):
- Represents a Google Drive file
- Always uses `supports_all_drives: true` for Shared Drive compatibility
- Methods:
  - `copy(name:, parent:, description:)` - Copy file to new location
  - `api_object` - Access underlying Google API file object (fields: id, name, kind, parents)

## Key Implementation Details

1. **Sheet name escaping**: All range references automatically wrap sheet names in single quotes to handle special characters
2. **Shared Drive support**: Drive operations include `supports_all_drives: true` parameter
3. **Batching**: Large sheet updates are batched in 10,000-row chunks with dynamic delays based on API response time
4. **Service caching**: Each module caches its Google API service instance (`@service`)
5. **Nil handling**: `GSuiteAPI.map_nils_to_empty_strings!` helper converts nil values to empty strings in value arrays
