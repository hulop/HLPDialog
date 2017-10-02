# HLPDialog

## Map navigation dialog framework
HLPDialog is a map navigation dialog framework for iOS. It includes utilities and UIs for dialog.

## Dependencies
- [Watson Developer Cloud Swift SDK](https://github.com/watson-developer-cloud/swift-sdk) (Apache 2.0)

## Installation

1. Install [Carthage](https://github.com/Carthage/Carthage).
2. Add below to your `Cartfile`:
```
github "hulop/HLPDialog"
```
3. In your project directory, run `carthage update HLPDialog`.

## Usage

### Choose Conversation Service
This framework communicates Conversation Service. You should choose one of these service.

- https://github.com/hulop/ConversationService
- https://github.com/hulop/ConversationServiceWatson

### Setup dialog
Set Conversation Service credential.
```swift
let config = ["conv_server": "your server host name",
              "conv_api_key": "your API key",
              "conv_client_id": "client ID"]
DialogManager.sharedManager().config = config
```

### Invoke when dialog availability changed
If you want to receive Conversation Service availability changed event, define notification named `DialogManager.DIALOG_AVAILABILITY_CHANGED_NOTIFICATION`.
```swift
NotificationCenter.default.addObserver(self, selector: #selector(dialogStatusChanged), name: DialogManager.DIALOG_AVAILABILITY_CHANGED_NOTIFICATION, object: nil)
```

### Microphone button
```swift
dialogHelper = DialogViewHelper()
let scale:CGFloat = 0.75
let size = (113*scale)/2
let x = size+8
let y = self.view.bounds.size.height - (size+8)
if let dh = dialogHelper {
    dh.subColor = UIColor.black.cgColor
    dh.mainColor = UIColor.green.cgColor
    dh.scale = scale
    dh.inactive()
    dh.setup(self.view, position:CGPoint(x: x, y: y))
    dh.delegate = self
    self.updateView()
}
```

`DialogViewDelegate` implementation defines button tapped event.

```swift
func dialogViewTapped() {
  // your code
}
```

### Setup dialog view
```swift
let dialogView = DialogViewController()
/* set delegate for text to speech (TTSProtocol implementation) */
dialogView.tts = DummyTTS()
/* if you want to recycle DialogViewHelper instance, set it to baseHelper.
  dialog view will inherit colors of microphone button.
*/
dialogView.baseHelper = dialogHelper
self.navigationController?.pushViewController(dialogView, animated: true)
```

----
## DialogManager
- `isActive` **readonly** - Is dialog view appeared
- `config` - Set Conversation Service setting
  - Setting keys:
    - `"conv_server"` - Server host name
    - `"conv_api_key"` - API Key
    - `"conv_client_id"` - Client ID (such as Device ID)
- `useHttps` (default: true) -  Use HTTPS to access server
- `userMode` - Set the names of dialog scripts
  - These script names are available
    - `user_blind` -  For blind users
    - `user_wheelchair` - For wheel chair users
    - `user_general` (default) - For all sighted users
- `isAvailable` **readonly** - Is Conversation Service available
- `sharedManager()`
  - Get DialogManager instance
- `pause()`
  - Pause dialog
- `action()`
  - Toggle dialog on/off
- `end()`
  - Finish dialog and go back previous view
- `changeLocation(lat:lng:floor:)`
  - Set current location
- `changeBuilding(_:)`
  - Set current building

----
## About
[About HULOP](https://github.com/hulop/00Readme)

## License
[MIT](https://opensource.org/licenses/MIT)

## README
This Human Scale Localization Platform library is intended solely for use with an Apple iOS product and intended to be used in conjunction with officially licensed Apple development tools and further customized and distributed under the terms and conditions of your licensed Apple developer program.
