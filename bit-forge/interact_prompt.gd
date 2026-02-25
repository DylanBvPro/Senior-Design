extends Label

func _ready():
	Messenger.SHOW_INTERACT_MESSAGE.connect(onInteractMessage)
	Messenger.CLEAR_INTERACT_MESSAGE.connect(func(): hide())


func onInteractMessage(message:String):
	if (message == ""):
		hide()
		
	if (text != message):
		text = message
	
	if (!visible):
		show()
