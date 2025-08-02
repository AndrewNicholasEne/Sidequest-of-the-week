using System.Text.Json;
using Amazon.Lambda.Core;
using Amazon.S3;
using Amazon.S3.Model;
using WeeklyQuestSender.Models;

// Assembly attribute to enable the Lambda function's JSON input to be converted into a .NET class.
[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace WeeklyQuestSender;

public class Function(IAmazonS3 s3Client)
{
    private const string BucketNameEnv = "QUEST_BUCKET";
    private const string ObjectKey = "quests.json";

    public Function() : this(new AmazonS3Client()) {}

    public async Task<string> FunctionHandler(object _, ILambdaContext context)
    {
        var bucket = Environment.GetEnvironmentVariable("QUEST_BUCKET");
        context.Logger.LogLine($"Bucket: {bucket}");
        context.Logger.LogLine($"About to fetch {ObjectKey}");

        var request = new GetObjectRequest { BucketName = bucket, Key = ObjectKey };

        try
        {
            using var response = await s3Client.GetObjectAsync(request);
            using var reader = new StreamReader(response.ResponseStream);
            var json = await reader.ReadToEndAsync();
            context.Logger.LogLine($"Raw JSON: {json}");

            var questList = JsonSerializer.Deserialize<QuestList>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

            if (questList?.Quests == null || !questList.Quests.Any())
            {
                context.Logger.LogLine("No quests found in parsed JSON.");
                return "No quest found.";
            }

            var selectedQuest = questList.Quests.OrderBy(q => Guid.NewGuid()).FirstOrDefault();
            context.Logger.LogLine($"Selected quest: {selectedQuest?.Description}");

            return selectedQuest?.Description ?? "No quest found.";
        }
        catch (Exception ex)
        {
            context.Logger.LogLine($"Exception: {ex}");
            return "Error reading quest.";
        }
    }

}