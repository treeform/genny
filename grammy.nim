import openai


let text = "Hej ho are u doing? Im g sending the emaill now."

var messages = @[
  ConversationMessage(
    role: "user",
    content: &"""
Please correct spelling and grammar in the following text:

""" + text
  )
]

echo messages
echo talkToAI(messages)
