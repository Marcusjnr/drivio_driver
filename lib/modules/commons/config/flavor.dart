/// Build flavor. Matches the native Android productFlavors / iOS schemes
/// (`prod`, `staging`) — `Flavor.name` picks the dotenv file
/// (`.env.prod` / `.env.staging`), so the enum cases must stay in sync with
/// the native flavor names.
enum Flavor { prod, staging }
