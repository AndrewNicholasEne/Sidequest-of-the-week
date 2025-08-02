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

    public async Task<string> FunctionHandler(string input, ILambdaContext context)
    {
        var bucket = Environment.GetEnvironmentVariable(BucketNameEnv);

        if (string.IsNullOrEmpty(bucket))
            throw new Exception("QUEST_BUCKET environment variable is not set.");

        var request = new GetObjectRequest
        {
            BucketName = bucket,
            Key = ObjectKey
        };

        using var response = await s3Client.GetObjectAsync(request);
        using var reader = new StreamReader(response.ResponseStream);
        var json = await reader.ReadToEndAsync();

        var questList = JsonSerializer.Deserialize<QuestList>(json);

        var selectedQuest = questList?.Quests?.OrderBy(q => Guid.NewGuid()).FirstOrDefault();

        return selectedQuest?.Description ?? "No quest found.";
    }
}