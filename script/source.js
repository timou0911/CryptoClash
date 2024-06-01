const prompt = args[0];

// requests: OpenAI API using Functions
const openAIResponse = await Functions.makeHttpRequest({
    // url: URL of the API endpoint (required)
    url: `https://api.openai.com/v1/chat/completions`,
    // defaults to 'GET' (optional)
    method: "POST", 
    // headers: supplied as an object (optional)
    headers: { 
    "Content-Type": "application/json",
        Authorization: `Bearer ${secrets.apiKey}`
    },
    // defines: data payload (request body as an object).
    data: {
        // AI model to use
        "model": "gpt-4o",
        // messages: array of messages to send to the model
        "messages": [
        {
            // role: role of the message sender (either "user" or "system")
            "role": "system",
            // content: message content (required)
            "content": "you only reply a new number"
        },
        {
            "role": "user",
            "content": prompt
        }
    ]},
    // timeout: maximum request duration in ms (optional)
   
    // maxTokens: maximum number of tokens to spend on the request (optional)
    maxTokens: 100,
    // responseType: expected response type (optional, defaults to 'json')
    responseType: "json"
})
if (openAIResponse.error) {
  throw new Error(JSON.stringify(openAIResponse));
}

const result = openAIResponse.data.choices[0].message.content;

console.log(result);
return Functions.encodeString(result);