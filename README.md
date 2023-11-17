
# Plugin for ChatGPT for MSM

## MSM ChatGPT Integration


## ChatGPT Integration 

This plugin allows you to query ChatGPT for a response based on the ticket description to send a response back from ChatGPT. The service uses the Azure OpenAI Service which can be accessed here: https://portal.azure.com/#view/Microsoft_Azure_ProjectOxford/CognitiveServicesHub/~/overview. You can also get more information on this service here: https://azure.microsoft.com/en-ca/products/ai-services/openai-service

The model used for integratoin is based on your selections when creating the OpenAI instance in Azure.

## Compatible Versions

| Plugin  | MSM         | 
|---------|-------------|
| x.x.x   | 14.+        |
| x.x.x   | 15.+        |

## Installation


Once the plugin has been installed you will need to configure the following settings within the plugin page:

+ *MSM API Key* : The API key for the user created within MSM to perfom these actions.
+ *ChatGPT API Key* : The API key for ChatGPT.
+ *ChatGPT API Endpoint* : This is the endpoint used by the integration to access your instance of ChatGPT, an example is this "https://openaiinstance.openai.azure.com/openai/deployments/marvalaudeployment/chat/completions?api-version=2023-07-01-preview". This value will be determined by the version and instance name of you model. To get this information, you need to login to https://oai.azure.com/portal/, navigate to your model, then click on "Chat". Under "Chat Session" click on "View Code" then select curl in the drop down. THe address for curl is the same endpoint you use here.
+ *ID of Dictionary to update* : Currently Unused.
+ *DB Connection String (optional)*: Currently Unused.

## Usage

The plugin can be launched from the quick menu after you load a request.

## Contributing

We welcome all feedback including feature requests and bug reports.
