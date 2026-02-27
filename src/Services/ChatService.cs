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
        private readonly ProductService _productService;
        private readonly string? _endpoint;
        private readonly string _deploymentName;

        public ChatService(ILogger<ChatService> logger, IConfiguration configuration, ProductService productService)
        {
            _logger = logger;
            _configuration = configuration;
            _productService = productService;
            _httpClient = new HttpClient();
            _endpoint = _configuration["AzureAI:Endpoint"];
            _deploymentName = _configuration["AzureAI:DeploymentName"] ?? "Phi-4";
        }

        private string GetProductCatalogContext()
        {
            var products = _productService.GetAllProducts();
            var sb = new StringBuilder();
            sb.AppendLine("Here is our current product catalog:");
            foreach (var product in products)
            {
                sb.AppendLine($"- {product.Name}: {product.Description} Price: ${product.Price:F2}");
            }
            return sb.ToString();
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

                // Get token using AzureCliCredential for local development
                var credential = new AzureCliCredential();
                var token = await credential.GetTokenAsync(
                    new Azure.Core.TokenRequestContext(new[] { "https://cognitiveservices.azure.com/.default" }));

                _httpClient.DefaultRequestHeaders.Authorization = 
                    new AuthenticationHeaderValue("Bearer", token.Token);

                var productCatalog = GetProductCatalogContext();
                var systemPrompt = $@"You are a helpful assistant for Zava Storefront. Help customers with product inquiries and general questions.

{productCatalog}

When customers ask about products, pricing, or recommendations, use the above catalog to provide accurate information.";

                var requestBody = new
                {
                    messages = new[]
                    {
                        new { role = "system", content = systemPrompt },
                        new { role = "user", content = userMessage }
                    },
                    model = _deploymentName,
                    max_tokens = 800
                };

                var json = JsonSerializer.Serialize(requestBody);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                // Microsoft format models (like Phi-4) use /models/ endpoint, OpenAI models use /openai/deployments/
                var isMicrosoftModel = _deploymentName.StartsWith("Phi", StringComparison.OrdinalIgnoreCase);
                string chatEndpoint;
                if (isMicrosoftModel)
                {
                    chatEndpoint = $"{_endpoint.TrimEnd('/')}/models/chat/completions?api-version=2024-05-01-preview";
                }
                else
                {
                    chatEndpoint = $"{_endpoint.TrimEnd('/')}/openai/deployments/{_deploymentName}/chat/completions?api-version=2024-10-21";
                }
                _logger.LogInformation("Calling endpoint: {Endpoint}", chatEndpoint);
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
