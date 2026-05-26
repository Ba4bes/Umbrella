// =============================================================================
// Umbrella API — ASP.NET Core 10 Minimal API
//
// INTENTIONAL VULNERABILITIES (broken baseline — see broken.bicep):
//   1. POST /words uses string-concatenated SQL → SQL injection demo
//      (Defender for Databases alert trigger)
//   2. GET /debug/exec executes arbitrary shell commands when
//      ENABLE_DEBUG_EXEC=true → App Service runtime anomaly alert trigger
//   3. Connection string read from plain app setting, not a Key Vault reference
//
// The "fixed" deployment slot sets ENABLE_DEBUG_EXEC=false, uses parameterized
// queries (EF Core), and references the connection string via a Key Vault
// reference bound through Managed Identity.
// =============================================================================

using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);
 // ── Azure Storage Configuration Service ────────────────────────────────────
 // Reads app configuration from config.json in blob storage (broken baseline).
 // In the broken baseline, the blob is publicly readable (misconfig #1).
 builder.Services.AddSingleton<AppConfigService>();

// ── CORS: allow the Static Web App origin ──────────────────────────────────
builder.Services.AddCors(options =>
    options.AddDefaultPolicy(policy =>
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader()));

// ── Connection string ─────────────────────────────────────────────────────
// BROKEN: read directly from an app setting (plain text).
// FIXED:  the same app setting name will hold a Key Vault reference
//         (@Microsoft.KeyVault(SecretUri=...)) resolved via Managed Identity.
var connectionString = builder.Configuration["SqlConnectionString"]
    ?? throw new InvalidOperationException(
        "SqlConnectionString app setting is missing. " +
        "Set it in App Service → Configuration or via a Key Vault reference.");

// ── EF Core (used by GET /words and the fixed POST /words path) ───────────
builder.Services.AddDbContext<WordsDbContext>(options =>
    options.UseSqlServer(connectionString));

var app = builder.Build();

app.UseCors();

// Ensure the Words table exists (idempotent on every cold start)
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<WordsDbContext>();
    db.Database.EnsureCreated();
}

 // Load app configuration from blob storage (config.json in assets container)
 try
 {
     var configService = app.Services.GetRequiredService<AppConfigService>();
     await configService.LoadConfigAsync();
 }
 catch (Exception ex)
 {
     // If config loading fails, app continues with default values
     Console.WriteLine($"Warning: Failed to load config.json from blob storage: {ex.Message}");
 }
// ── GET /health ───────────────────────────────────────────────────────────
app.MapGet("/health", () =>
    Results.Ok(new { status = "healthy", utc = DateTime.UtcNow }));

 // ── GET /config ───────────────────────────────────────────────────────────
 // Returns the current app configuration loaded from blob storage.
 // In the broken baseline, the config.json is publicly readable, allowing anyone
 // to download the configuration and potentially modify it.
 app.MapGet("/config", (AppConfigService configService) =>
     Results.Ok(configService.GetConfig()));

// ── GET /words ────────────────────────────────────────────────────────────
app.MapGet("/words", async (WordsDbContext db) =>
{
    var words = await db.Words
        .OrderByDescending(w => w.Count)
        .Select(w => new { w.Text, w.Count })
        .ToListAsync();
    return Results.Ok(words);
});

// ── POST /words ───────────────────────────────────────────────────────────
// INTENTIONAL VULNERABILITY: raw string interpolation in SQL.
// Submit `'; DROP TABLE Words;--` to trigger a Defender for Databases alert.
app.MapPost("/words", async (WordInput input) =>
{
    if (string.IsNullOrWhiteSpace(input.Word))
        return Results.BadRequest(new { error = "Word cannot be empty." });

    if (input.Word.Length > 200)
        return Results.BadRequest(new { error = "Word exceeds maximum length." });

    // BROKEN: direct string interpolation — do not use in production
    await using var conn = new SqlConnection(connectionString);
    await conn.OpenAsync();

    var cmd = conn.CreateCommand();
    cmd.CommandText =
        $"IF EXISTS (SELECT 1 FROM Words WHERE Text = '{input.Word}') " +
        $"  UPDATE Words SET Count = Count + 1 WHERE Text = '{input.Word}' " +
        $"ELSE " +
        $"  INSERT INTO Words (Text, Count) VALUES ('{input.Word}', 1)";

    await cmd.ExecuteNonQueryAsync();
    return Results.Ok(new { message = "Word recorded." });
});

// ── DELETE /words ─────────────────────────────────────────────────────────
// Clears the entire word cloud (all rows in the Words table).
// Use this to reset between demo runs.
app.MapDelete("/words", async (WordsDbContext db) =>
{
    await db.Words.ExecuteDeleteAsync();
    return Results.Ok(new { message = "Word cloud reset." });
});

// ── GET /debug/exec (BROKEN BASELINE ONLY) ───────────────────────────────
// INTENTIONAL VULNERABILITY: executes the `cmd` query-string parameter as a
// shell command on the App Service Linux container.
//
// Demo trigger: GET /debug/exec?cmd=whoami
// Expected Defender for App Service alert: "Suspicious process execution" /
// "Command-line attack tool detected"
//
// Controlled by the ENABLE_DEBUG_EXEC app setting (set to "true" in
// broken.bicep, absent in fixed.bicep).
if (builder.Configuration["ENABLE_DEBUG_EXEC"] == "true")
{
    app.MapGet("/debug/exec", async (string? cmd) =>
    {
        if (string.IsNullOrWhiteSpace(cmd))
            return Results.BadRequest(new { error = "cmd query parameter is required." });

        var psi = new System.Diagnostics.ProcessStartInfo("/bin/sh", $"-c \"{cmd}\"")
        {
            RedirectStandardOutput = true,
            RedirectStandardError  = true,
            UseShellExecute        = false,
        };

        using var process = System.Diagnostics.Process.Start(psi)!;
        var stdout = await process.StandardOutput.ReadToEndAsync();
        var stderr = await process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();

        return Results.Ok(new
        {
            stdout,
            stderr,
            exitCode = process.ExitCode,
        });
    });
}

app.Run();

// ── Request / domain models ───────────────────────────────────────────────
record WordInput(string Word);

public class Word
{
    public int    Id    { get; set; }
    public required string Text  { get; set; }
    public int    Count { get; set; }
}

public class WordsDbContext : DbContext
{
    public WordsDbContext(DbContextOptions<WordsDbContext> options) : base(options) { }

    public DbSet<Word> Words => Set<Word>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Word>(entity =>
        {
            entity.HasKey(w => w.Id);
            entity.Property(w => w.Text).HasMaxLength(200).IsRequired();
            entity.HasIndex(w => w.Text).IsUnique();
        });
    }
}

 // ── Application Configuration ────────────────────────────────────────────────
 public class AppConfig
 {
     public int MaxWordsDisplay { get; set; } = 100;
     public int WordCloudRefreshSeconds { get; set; } = 3;
     public int MinWordLength { get; set; } = 2;
     public int MaxWordLength { get; set; } = 50;
     public string ColorScheme { get; set; } = "iris";
 }

 // ── Application Configuration Service ─────────────────────────────────────
 // Reads config.json from blob storage (assets container).
 // In the broken baseline, the blob is publicly readable.
 // In the fixed baseline, access is restricted via Managed Identity.
 // ── Application Configuration Service ─────────────────────────────────
 // Reads config.json from blob storage (assets container).
 // In the broken baseline, the blob is publicly readable.
 // In the fixed baseline, access is restricted via Managed Identity.
 public class AppConfigService
 {
     private AppConfig _config = new();

     public async Task LoadConfigAsync()
     {
         try
         {
             // BROKEN baseline: The blob is publicly readable (misconfig #1: publicAccess = 'Blob').
             // FIXED baseline: Access restricted via Managed Identity to the storage account.
             // Try to read config.json from blob storage.
             // Storage account name is resolved from the STORAGE_ACCOUNT_NAME environment variable,
             // set by the Bicep template. Falls back to HTTP public access in broken baseline.
             var storageAccountName = Environment.GetEnvironmentVariable("STORAGE_ACCOUNT_NAME") ?? "umbrellast";
             var blobUri = new Uri($"https://{storageAccountName}.blob.core.windows.net/assets/config.json");

             // Try with DefaultAzureCredential (Managed Identity in fixed, public HTTP fallback in broken)
             try
             {
                 var blobClient = new Azure.Storage.Blobs.BlobClient(blobUri, new Azure.Identity.DefaultAzureCredential());
                 var download = await blobClient.DownloadAsync();
                 using var reader = new System.IO.StreamReader(download.Value.Content);
                 var json = await reader.ReadToEndAsync();
                 var loaded = Newtonsoft.Json.JsonConvert.DeserializeObject<AppConfig>(json);
                 if (loaded != null)
                     _config = loaded;
             }
             catch (Azure.Identity.AuthenticationFailedException)
             {
                 // Managed Identity failed (broken baseline has no identity), fall back to public HTTP
                 Console.WriteLine("Managed Identity unavailable, attempting public blob access...");
                 using var httpClient = new HttpClient();
                 var response = await httpClient.GetAsync(blobUri);
                 if (response.IsSuccessStatusCode)
                 {
                     var json = await response.Content.ReadAsStringAsync();
                     var loaded = Newtonsoft.Json.JsonConvert.DeserializeObject<AppConfig>(json);
                     if (loaded != null)
                         _config = loaded;
                 }
             }
         }
         catch (Exception ex)
         {
             Console.WriteLine($"Failed to load config.json: {ex.Message}");
             // Continue with default configuration
         }
     }

     public AppConfig GetConfig() => _config;
 }
