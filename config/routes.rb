Paperclip::Engine.routes.draw do 
	get 'private/:class_name/:id/:attachment/:style', controller: 'paperclip/private', action: 'download'
end