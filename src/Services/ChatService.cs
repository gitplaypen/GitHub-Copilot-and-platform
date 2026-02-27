using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Azure.Identity;
using ZavaStorefront.Models;

namespace ZavaStorefront.Services
{
    public class ChatService
    {
        private readonly ILogger<ChatService> _logger;
        private readonly IConfiguration _configuration;
        private readonly HttpClient _httpClient;
        private readonly string? _endpoint;
        private readonly string _deploymentName;

        public ChatService(ILogger<ChatService> logger, IConfiguration configuration)
        {
            _logger = logger;
            _configuration = configuration;
            _httpClient = new HttpClient();
            _endpoint = _configuration["AzureAI:Endpoint"];
            _deploymentName = _configuration["AzureAI:DeploymentName"] ?? "Phi-4";
        }

        public async Task<ChatResponse> SendMessageAsync(string userMessage)
        {
            if (string.IsNullOrEmpty(_endpoint))
            {
                _logger.LogWarning("Chat client not configured");
                return new ChatResponse
                {
                    Success = false,
                    Error = "Chat service is not configured. Please set the AzureAI:Endpoint configuration."
                };
            }

            try
            {
                _logger.LogInformation("Sending message to AI model");

                // Get token using DefaultAzureCredential
                var credential = new DefaultAzureCredential();
                var token = await credential.GetTokenAsync(
                    new Azure.Core.TokenRequestContext(new[] { "https://cognitiveservices.azure.com/.default" }));

                _httpClient.DefaultRequestHeaders.Authorization = 
                    new AuthenticationHeaderValue("Bearer", token.Token);

                var requestBody = new
                {
                    messages = new[]
                    {
                        new { role = "system", content = "You are a helpful assistant for Zava Storefront. Help customers with product inquiries and general questions." },
                        new { role = "user", content = userMessage }
                    },
                    model = _deploymentName,
                    max_tokens = 800
                };

                var json = JsonSerializer.Serialize(requestBody);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var chatEndpoint = $"{_endpoint.TrimEnd('/')}/openai/deployments/{_deploymentName}/chat/completions?api-version=2024-02-01";
                var response = await _httpClient.PostAsync(chatEndpoint, content);

                if (!response.IsSuccessStatusCode)
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    _logger.LogError("API error: {StatusCode} - {Content}", response.StatusCode, errorContent);
                    return new ChatResponse
                    {
                        Success = false,
                        Error = $"API error: {response.StatusCode}"
                    };
                }

                var responseJson = await response.Content.ReadAsStringAsync();
                using var doc = JsonDocument.Parse(responseJson);
                var assistantMessage = doc.RootElement
                    .GetProperty("choices")[0]
                    .GetProperty("message")
                    .GetProperty("content")
                    .GetString();

                _logger.LogInformation("Received response from AI model");

                return new ChatResponse
                {
                    Success = true,
                    Response = assistantMessage ?? "No response received"
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error communicating with AI model");
                return new ChatResponse
                {
                    Success = false,
                    Error = $"Error: {ex.Message}"
                };
            }
        }
    }
}
