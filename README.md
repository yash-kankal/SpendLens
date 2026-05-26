# SpendLens

A personal finance app for iOS. Track what you spend, stay inside your budget, and split bills with friends.

Built with SwiftUI and Supabase. AI features (categorization, insights, chat) run through a Supabase Edge Function that calls the OpenAI API, so the key never touches the device.

---

## Features

- Log expenses and tag them by category
- Monthly budget with per-category limits
- Dashboard, analytics, and spending trends
- AI-powered category suggestions and budget insights
- Ask the AI anything about your spending
- Split bills with friends and track balances
- Export expenses as CSV
- Light / dark / system theme

---

## Setup

```sh
open SpendLens.xcodeproj
```

Copy the example config and fill in your Supabase credentials:

```sh
cp App/SupabaseConfig.example.plist App/SupabaseConfig.plist
```

Add your `SUPABASE_URL` and `SUPABASE_ANON_KEY` — both are in your Supabase project settings under API.

Then run the schema to create the tables and RLS policies:

```
supabase/schema.sql
```

For AI features, deploy `supabase/functions/ai/index.ts` and set `OPENAI_API_KEY` in your Supabase Edge Function secrets.

---

`App/SupabaseConfig.plist` is gitignored. The example file is committed so the setup is reproducible.
