using System.Text.Json;
using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.Model;
using Amazon.Lambda.Core;
using Amazon.S3;
using Amazon.S3.Model;
using Amazon.SimpleEmailV2;
using Amazon.SimpleEmailV2.Model;
using WeeklyQuestSender.Models;

// Assembly attribute to enable the Lambda function's JSON input to be converted into a .NET class.
[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace WeeklyQuestSender;

public class Function(IAmazonS3 s3Client, AmazonDynamoDBClient dbClient)
{
    private const string BucketNameEnv = "QUEST_BUCKET";
    private const string ObjectKey = "quests.json";
    private const string TableNameEnv = "SUBSCRIBERS_TABLE";

    public Function() : this(new AmazonS3Client(), new AmazonDynamoDBClient())
    {
    }

    public async Task<string> FunctionHandler(object _, ILambdaContext context)
    {
        var bucket = Environment.GetEnvironmentVariable("QUEST_BUCKET");
        context.Logger.LogLine($"Bucket: {bucket}");
        context.Logger.LogLine($"About to fetch {ObjectKey}");

        var request = new GetObjectRequest {BucketName = bucket, Key = ObjectKey};

        try
        {
            using var response = await s3Client.GetObjectAsync(request);
            using var reader = new StreamReader(response.ResponseStream);
            var json = await reader.ReadToEndAsync();
            context.Logger.LogLine($"Raw JSON: {json}");

            var questList = JsonSerializer.Deserialize<QuestList>(json,
                new JsonSerializerOptions {PropertyNameCaseInsensitive = true});

            if (questList?.Quests == null || !questList.Quests.Any())
            {
                context.Logger.LogLine("No quests found in parsed JSON.");
                return "No quest found.";
            }

            var selectedQuest = questList.Quests.OrderBy(q => Guid.NewGuid()).FirstOrDefault();
            context.Logger.LogLine($"Selected quest: {selectedQuest?.Description}");

            var subscribers = await GetConfirmedSubscribersAsync(context);

            await SendQuestToSubscribers(selectedQuest!.Description, subscribers, context);

            return selectedQuest?.Description ?? "No quest found.";
        }
        catch (Exception ex)
        {
            context.Logger.LogLine($"Exception: {ex}");
            return "Error reading quest.";
        }
    }

    private async Task<List<Subscriber>> GetConfirmedSubscribersAsync(ILambdaContext context)
    {
        var table = Environment.GetEnvironmentVariable(TableNameEnv);
        context.Logger.LogLine($"DynamoDB table: {table}");

        var scanRequest = new ScanRequest
        {
            TableName = table,
        };

        var response = await dbClient.ScanAsync(scanRequest);
        var subscribers = response.Items
            .Select(item => new Subscriber
                {Id = item["id"].S, Email = item["email"].S,})
            .ToList();

        context.Logger.LogLine($"Found {subscribers.Count} confirmed subscribers.");
        return subscribers;
    }

    private async Task SendQuestToSubscribers(string quest, List<Subscriber> subscribers, ILambdaContext context)
    {
        var ses = new AmazonSimpleEmailServiceV2Client();
        var templateName = Environment.GetEnvironmentVariable("SES_TEMPLATE");
        var fromAddress = Environment.GetEnvironmentVariable("SES_FROM");

        foreach (var sub in subscribers)
        {
            var request = new SendEmailRequest
            {
                FromEmailAddress = fromAddress,
                Destination = new Destination
                {
                    ToAddresses = [sub.Email]
                },
                Content = new EmailContent
                {
                    Template = new Template
                    {
                        TemplateName = templateName,
                        TemplateData = JsonSerializer.Serialize(new {quest = quest})
                    }
                }
            };

            try
            {
                var response = await ses.SendEmailAsync(request);
                context.Logger.LogLine($"Email sent to {sub.Email}, SES status: {response.HttpStatusCode}");
            }
            catch (Exception ex)
            {
                context.Logger.LogLine($"Failed to send to {sub.Email}: {ex.Message}");
            }
        }
    }
}