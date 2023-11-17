<%@ WebHandler Language = "C#" Class="ApiHandler" %>

using System;
using System.IO;
using System.Net;
using System.Text;
using System.Web;
using System.Dynamic;
using System.Collections.Generic;
using System.Globalization;
using System.Web.Script.Serialization;
using Serilog;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using MarvalSoftware;
using MarvalSoftware.UI.WebUI.ServiceDesk.RFP.Plugins;
using MarvalSoftware.ServiceDesk.Facade;
using MarvalSoftware.DataTransferObjects;
using System.Threading.Tasks;
using System.Linq;
using System.Xml;
using System.Xml.Linq;
using System.Linq;
using System.Text.RegularExpressions;
using System.Xml.Serialization;
using System.Data.SqlClient;
using Newtonsoft.Json.Serialization;

using Microsoft.Win32;

/// <summary>
/// ApiHandler
/// </summary>
public class ApiHandler : PluginHandler
{


   private string DBConnectionStringFromConfig { get { return this.GlobalSettings["@@DBConnectionString"]; } }

   private int DictionaryIDFromConfig { get { return Int32.Parse(this.GlobalSettings["@@DictionaryID"]); } }

    private string ChatGPTEndpoint { get { return this.GlobalSettings["@@APIEndpoint"]; } }

    public class GPTContent
        {
            public string content { get; set; }
            public string role { get; set; }
        }
    public class ChatGPTQuery
        {
            public int? stop { get; set; }
            public int frequency_penalty { get; set; }
            public int presence_penalty { get; set; }
            public double top_p { get; set; }
            public int max_tokens { get; set; }
            public double temperature { get; set; }
            public List<GPTContent> messages { get; set; }
        }
    
    //properties
  
public class dictObject
    {
        public List<object> ConfigParams { get; set; }
        public List<object> RequestParams { get; set; }
        public int SolvedState { get; set; }
    }

    private string MSMAPIKey
    {
        get
        {
            return this.GlobalSettings["@@MSMAPIKey"];
        }
    }


    private IWebProxy Proxy
    {
        get
        {
            IWebProxy proxy = System.Net.WebRequest.GetSystemWebProxy();
            if (proxy != null && this.ProxyCredentials != null)
            {
                proxy.Credentials = this.ProxyCredentials;
            }
            return proxy;
        }
    }

    private string ProxyUsername
    {
        get
        {
            return "";
        }
    }

    private string ProxyPassword
    {
        get
        {
            return GlobalSettings["@@ProxyPassword"];
        }
    }

    private ICredentials ProxyCredentials
    {
        get
        {
            if (String.IsNullOrWhiteSpace(this.ProxyUsername))
                return null;
            return new NetworkCredential(this.ProxyUsername, this.ProxyPassword);
        }
    }

    private string FacilitiesGoogleMapsIssueNo { get; set; }

    private string FacilitiesGoogleMapsSummary { get; set; }

    private string currentHostname { get; set; }

    private string FacilitiesGoogleMapsType { get; set; }

    private string msmRequestDescription { get; set; }

    private string FacilitiesGoogleMapsProject { get; set; }

    private string FacilitiesGoogleMapsReporter { get; set; }

    private string AttachmentIds { get; set; }

    private string MsmContactEmail { get; set; }

    private string IssueUrl { get; set; }

    //fields
    private int msmRequestNo;
    private int msmRequestID;

    private static readonly int second = 1;
    private static readonly int minute = 60 * ApiHandler.second;
    private static readonly int hour = 60 * ApiHandler.minute;
    private static readonly int day = 24 * ApiHandler.hour;

    /// <summary>
    /// Handle Request
    /// </summary>
    public override void HandleRequest(HttpContext context)
    {
        this.ProcessParamaters(context.Request);
        var action = context.Request.QueryString["action"];
        this.RouteRequest(action, context);
    }

    public override bool IsReusable
    {
        get { return false; }
    }

    /// <summary>
    /// Get Paramaters from QueryString
    /// </summary>
    private void ProcessParamaters(HttpRequest httpRequest)
    {
        int.TryParse(httpRequest.Params["requestNumber"], out this.msmRequestNo);
        int.TryParse(httpRequest.Params["requestID"], out this.msmRequestID);
        this.msmRequestDescription = httpRequest.Params["requestDescription"] ?? string.Empty;
        this.currentHostname = httpRequest.Params["currentHostname"] ?? string.Empty;
       
        this.AttachmentIds = httpRequest.Params["attachments"] ?? string.Empty;
        this.MsmContactEmail = httpRequest.Params["contactEmail"] ?? string.Empty;
        this.IssueUrl = httpRequest.Params["issueUrl"] ?? string.Empty;
    }

    public class FacilitiesGoogleMapsIssueList
    {
        public string key { get; set; }
        public string summary { get; set; }
        public string status { get; set; }
        public string assignee { get; set; }
        public string self { get; set; }
        public string unlink { get; set; }
        public string href { get; set; }
    }
    /// <summary>
    /// Route Request via Action
    /// </summary>
    private void RouteRequest(string action, HttpContext context)
    {
        HttpWebRequest httpWebRequest;
        HttpWebRequest httpWebRequest2;
        switch (action)
        {
            case "PreRequisiteCheck":
                context.Response.Write(this.PreRequisiteCheck());
                break;
            case "ResolveRequest":
                DateTime currentTime = DateTime.Now;
                string formattedTime = currentTime.ToString("yyyy-MM-dd HH:mm:ss");
                List<int> serviceidList = new List<int>();
                var requestInformationURL = "https://" + currentHostname + "/MSM/api/serviceDesk/operational/requests/" + this.msmRequestID;
                Log.Information("Current hostname is  " + requestInformationURL);
                httpWebRequest = ApiHandler.BuildRequest(requestInformationURL, null, "GET", this.Proxy);
                var requestContent = ApiHandler.ProcessRequest(httpWebRequest, this.MSMAPIKey);
                dynamic requestContentObj = JsonConvert.DeserializeObject(requestContent);
                Log.Information("data from content for request is " + requestContent);
                List<dynamic> serviceHierarchy = requestContentObj.entity.data.serviceHierarchy.ToObject<List<dynamic>>();
               // var  = requestContentObj.entity.data.contact.name<String<dynamic>>();

                foreach (var item in serviceHierarchy)
{
    int id = item.id;       // Accessing the "id" property
    string name = item.name; // Accessing the "name" property
    serviceidList.Add(id);
    Log.Information("ID is " + id);
}
               var jsonObject = new
                  {
                       ServiceHierarchyIds = serviceidList,
                       WorkflowStatusId = 296,
                       updateOn = formattedTime
                    };
                // Log.Information("data from content for request is " + requestServiceHierarchy);
                context.Response.Write(requestContent);
                break;    
            case "GetChatGPTResponse":
                dynamic ChatGPTresult = QueryChatGPT();
                Log.Information("Have result from querying chatgpt as " + ChatGPTresult);
                context.Response.Write(ChatGPTresult);
                break;
             case "GetDictionaryList":
                
                Log.Information("Have dictionaryID as " + this.DictionaryIDFromConfig);
                dynamic Dictionaryresult = GetDictionaryList(this.DictionaryIDFromConfig);
                Log.Information("Have result from querying dictionary as " + Dictionaryresult);
                context.Response.Write(Dictionaryresult);
                break;
               case "GetNextStates":
                Log.Information("Have requestID as " + this.msmRequestID);
                dynamic NextstatesResult = GetNextRequestStates(this.msmRequestID);
                Log.Information("Have result from querying dictionary as " + NextstatesResult);
                context.Response.Write(NextstatesResult);
                break;
                
        }
    }

    /// <summary>
    /// Build a summary preview of the facilitiesgooglemaps issue to display in MSM
    /// </summary>
    /// <returns></returns>
   
    private string GetRequestBaseTypeIconUrl(int requestBaseType)
    {
        var baseRequestType = (MarvalSoftware.ServiceDesk.ServiceSupport.BaseRequestTypes)requestBaseType;
        string icon = baseRequestType.ToString().ToLower();
        if (icon == "changerequest")
        {
            icon = "change";
        }
        return string.Format("{0}{1}/Assets/Skins/{2}/Icons/{3}_32.png", HttpContext.Current.Request.Url.GetLeftPart(UriPartial.Authority), MarvalSoftware.UI.WebUI.ServiceDesk.WebHelper.ApplicationPath, MarvalSoftware.UI.WebUI.Style.StyleSheetManager.Skin, icon);
    }


    /// <summary>
    /// Create New FacilitiesGoogleMaps Issue
    /// </summary>

    private string QueryChatGPT()
    {

        ChatGPTQuery gptobj = new ChatGPTQuery() 
        {
           stop = null,
           frequency_penalty = 0,
           presence_penalty = 0,
           top_p = 0.95,
           temperature = 0.7,
           max_tokens = 800,
           messages = new List<GPTContent>()
            { 
                new GPTContent()
                {
                    content = msmRequestDescription,
                    role = "system"
                }
            
            }
        };
        
        string stringChatGPTResponse = JsonConvert.SerializeObject(gptobj);
        if (string.IsNullOrWhiteSpace(this.ChatGPTEndpoint)) {
             return "There is no Chat GPT API Endpoint in the plugin configuration, please update the Chat GPT API Endpoint in your configuration";
        
        } else {
        var httpWebRequest = ApiHandler.BuildRequest(ChatGPTEndpoint, stringChatGPTResponse, "POST", this.Proxy, "application/json");
        var AuthString = this.GlobalSettings["@@ChatGPTAPIKey"];
        return ApiHandler.ProcessRequest(httpWebRequest, AuthString);
        }
        
    }

    public class AzureUpdate
    {
        public string op { get; set; }
        public string path { get; set; }
        public int value { get; set; }
        public string from { get; set; }
    }
   
   
    /// <summary>
    /// Check and return missing plugin settings
    /// </summary>
    /// <returns>Json Object containing any settings that failed the check</returns>
    private JObject PreRequisiteCheck()
    {
        var preReqs = new JObject();
          if (string.IsNullOrWhiteSpace(this.ChatGPTEndpoint))
            {
                preReqs.Add("ChatGPTEndpoint", false);
            }
        //    if (string.IsNullOrWhiteSpace(this.Password))
        //     {
        //          preReqs.Add("facilitiesgooglemapsPassword", false);
        //     }
        return preReqs;
    }

    // Generic Methods

    /// <summary>
    /// Builds a HttpWebRequest
    /// </summary>
    /// <param name="uri">The uri for request</param>
    /// <param name="body">The body for the request</param>
    /// <param name="method">The verb for the request</param>
    /// <returns>The HttpWebRequest ready to be processed</returns>
    private static HttpWebRequest BuildRequest(string uri = null, string body = null, string method = "GET", IWebProxy proxy = null, string contentType = "application/json")
    {
        var request = WebRequest.Create(new UriBuilder(uri).Uri) as HttpWebRequest;
        //request.Proxy = proxy;
        request.Method = method.ToUpperInvariant();
        request.ContentType = contentType;

        if (body == null) return request;
        Log.Information("Body of request is " + body);
        using (var writer = new StreamWriter(request.GetRequestStream()))
        {
            writer.Write(body);
        }

        return request;
    }


private string GetAppPath(string productName)
    {
        const string foldersPath = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\Folders";
        var baseKey = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry64);

        var subKey = baseKey.OpenSubKey(foldersPath);
        if (subKey == null)
        {
            baseKey = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry32);
            subKey = baseKey.OpenSubKey(foldersPath);
        }
        return subKey != null ? subKey.GetValueNames().FirstOrDefault(kv => kv.Contains(productName)) : "ERROR";
    }
    /// <summary>
    /// Proccess a HttpWebRequest
    /// </summary>
    /// <param name="request">The HttpWebRequest</param>
    /// <param name="credentials">The Credentails to use for the API</param>
    /// <returns>Process Response</returns>
    private static string ProcessRequest(HttpWebRequest request, string credentials)
    {
        Log.Information("Sending request as " + request.Host);
        Log.Information("Sending URI as " + request.RequestUri);
        Log.Information("Sending Headers as " + request.Headers);

        try
        {
            // request.Headers.Add("Authorization", "Basic " + credentials);
            request.Headers.Add("Authorization", "Bearer " + credentials);
            request.Headers.Add("api-key", credentials);
            HttpWebResponse response = request.GetResponse() as HttpWebResponse;
            using (StreamReader reader = new StreamReader(response.GetResponseStream()))
            {
                return reader.ReadToEnd();
            }
        }
        catch (WebException ex)
        {
            return ex.Message;
        }
    }

      private string GetDBString()
    {
        string connectionString = "";
        string msmdLocation = GetAppPath("MSM");
        // Log.Information("Found MSMD at " + msmdLocation);
        string path = msmdLocation;
        string newPath = Path.GetFullPath(Path.Combine(path, @"..\"));
        // Log.Information("New Path is " + newPath);
        string openFilePath = newPath + "connectionStrings.config";
        XmlDocument xmlDoc = new XmlDocument();
        xmlDoc.Load(openFilePath);
        XmlNodeList nodeList = xmlDoc.SelectNodes("/appSettings/add[@key='DatabaseConnectionString']");
        if (nodeList.Count > 0)
        {
            // Get the value attribute of the node
            connectionString = nodeList[0].Attributes["value"].Value;
            // Log.Information("DatabaseConnectionString: " + connectionString);
        }
        else
        {
            // Log.Information("DatabaseConnectionString not found in the XML.");
        }
        if (connectionString == "")
        {
            Log.Information("Could not find connection string on the local machine");
            return DBConnectionStringFromConfig;
        }
        else
        {
            return connectionString;
        }
    }

    private string GetDictionaryList(int dictionaryID)
    {
        List<object> configParams = new List<object>();
        string DBConnectionString = GetDBString();
        // Log.Information("Have database connection string as " + DBConnectionString);
        configParams.Add(new { dictionaryID = dictionaryID });
        var connString = DBConnectionString;

        Log.Information("Running GetDictionaryList wtih params requestID " + dictionaryID);
        List<object> requestParams = new List<object>();
        using (SqlConnection conn = new SqlConnection(connString))
        {
            using (SqlCommand cmd = new SqlCommand())
            {
                cmd.CommandText = "dbo.classification_getForDict";
                cmd.CommandType = System.Data.CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@dictionaryId", dictionaryID);
                cmd.Connection = conn;
                conn.Open();
                requestParams.Add(new { classificationId = "0" ,description = ""});
                using (SqlDataReader sdr = cmd.ExecuteReader())
                {
                    while (sdr.Read())
                    {
                        // Log.Information("Found name as " + sdr["name"]);
                        // Log.Information("Found textvalue as " + sdr["textValue"]);
                        requestParams.Add(new
                        {
                            // CustomerId = sdr["locationId"],
                            classificationId = sdr["classificationId"],
                            description = sdr["description"]
                            // Country = sdr["description"]
                        });
                    }
                }
                conn.Close();
            }
            dictObject myObject = new dictObject
            {
                ConfigParams = configParams,
                RequestParams = requestParams
            };
            return (new JavaScriptSerializer().Serialize(myObject));
        }
    }

     private string GetNextRequestStates(int requestID)
    {
        List<object> configParams = new List<object>();
        string DBConnectionString = GetDBString();
        // Log.Information("Have database connection string as " + DBConnectionString);
        configParams.Add(new { requestID = requestID });
        var connString = DBConnectionString;
        int SolvedState = 0;
        Log.Information("Running GetNextRequestStates wtih params requestID " + requestID);
        List<object> requestParams = new List<object>();
        using (SqlConnection conn = new SqlConnection(connString))
        {
            using (SqlCommand cmd = new SqlCommand())
            {
                cmd.CommandText = "dbo.request_getNextStates";
                cmd.CommandType = System.Data.CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@identifier", requestID);
                cmd.Connection = conn;
                conn.Open();
                using (SqlDataReader sdr = cmd.ExecuteReader())
                {
                    while (sdr.Read())
                    {
                        // Log.Information("Found name as " + sdr["name"]);
                        // Log.Information("Found textvalue as " + sdr["textValue"]);
                        if (Convert.ToInt32(sdr["isSolvedState"]) > 0) {
                              SolvedState = 1;
                        }
                        requestParams.Add(new
                        {
                            // CustomerId = sdr["locationId"],
                            workflowStatusId = sdr["workflowStatusId"],
                            statusId = sdr["statusId"],
                            isSolvedState = sdr["isSolvedState"],
                            name = sdr["name"]
                            // Country = sdr["description"]
                        });
                    }
                }
                conn.Close();
            }
            dictObject myObject = new dictObject
            {
                ConfigParams = configParams,
                RequestParams = requestParams,
                SolvedState = SolvedState
            };
            return (new JavaScriptSerializer().Serialize(myObject));
        }
    }

    /// <summary>
    /// Encodes Credentials
    /// </summary>
    /// <param name="credentials">The string to encode</param>
    /// <returns>base64 encoded string</returns>
    private static string GetEncodedCredentials(string credentials)
    {
        var byteCredentials = Encoding.UTF8.GetBytes(credentials);
        return Convert.ToBase64String(byteCredentials);
    }

    /// <summary>
    /// JsonHelper Functions
    /// </summary>
    internal class JsonHelper
    {
        public static string ToJson(object obj)
        {
            return JsonConvert.SerializeObject(obj);
        }

        public static dynamic FromJson(string json)
        {
            return JObject.Parse(json);
        }
    }

    private string GetRelativeTime(DateTime date)
    {
        var ts = new TimeSpan(DateTime.Now.Ticks - date.Ticks);
        var delta = Math.Abs(ts.TotalSeconds);
        var localTimeOfDay = date.ToShortTimeString();

        if (delta < 1 * ApiHandler.minute)
        {
            return ts.Seconds == 1 ? this.GetResourceString("@@OneSecondAgo") : this.GetResourceString("@@AFewSecondsAgo");
        }

        if (delta < 2 * ApiHandler.minute)
        {
            return this.GetResourceString("@@OneMinuteAgo");
        }

        if (delta < 60 * ApiHandler.minute)
        {
            return this.GetResourceString("@@MinutesAgo", Math.Floor(ts.TotalMinutes));
        }

        if (delta < 61 * ApiHandler.minute)
        {
            return this.GetResourceString("@@OneHourAgo");
        }

        if (delta < 24 * ApiHandler.hour)
        {
            return this.GetResourceString("@@HoursAgo", Math.Floor(ts.TotalHours));
        }

        if (delta < 48 * ApiHandler.hour)
        {
            return this.GetResourceString("@@YesterdayAt", localTimeOfDay);
        }

        if (delta < 7 * ApiHandler.day)
        {
            return this.GetResourceString("@@DaysAgo", Math.Floor(ts.TotalDays));
        }

        return date.ToString("dd/MMM/yy hh:mm tt");
    }
}
