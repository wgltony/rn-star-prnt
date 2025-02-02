# rn-star-prnt

React Native bridge for [Star Micronics printers](http://www.starmicronics.com/pages/All-Products).  

This is a **minimal maintenance fork** of [`react-native-star-prnt`](https://github.com/infoxicator/react-native-star-prnt), focused on **keeping the package functional** with updated dependencies. I do not actively maintain or provide support for issues, but contributions are welcome!  

## Why This Fork?  

- The original package was outdated and had compatibility issues.  
- I updated the **iOS native code** to use the latest `xcframework` from [Star Micronics' official SDK](https://github.com/star-micronics/starprnt-sdk-ios-swift).  
- This **fixes issues running on the iOS simulator** and ensures compatibility with recent Xcode versions.  
- I **bumped dependencies**, ensuring the package works with recent React Native versions.  
- **Converted `.m` files to `.mm`** where necessary to support C++ code.  

### Why Not Use `react-native-star-io10`?  

The newer `react-native-star-io10` package is well-maintained, but it **completely breaks printing on the TSP100**, which is my target printer. This fork ensures the older implementation remains functional while staying compatible with modern React Native versions.  

---

## Installation  

```sh  
$ npm install rn-star-prnt --save  
```  

### Linking  

```sh  
$ react-native link rn-star-prnt  
```  

#### iOS Configuration  

1. Open Xcode, go to **Build Phases** > **Link Binary with Libraries**, and add the following frameworks:  
   - Go to `node_modules/rn-star-prnt/ios/Frameworks` and add `StarIO.xcframework` and `StarIO_Extension.xcframework`.  
   - Add `CoreBluetooth.framework` and `ExternalAccessory.framework`.  

2. Go to **Build Settings** > **Search Paths** and add:  
   ```sh  
   $(PROJECT_DIR)/../node_modules/rn-star-prnt/ios/Frameworks  
   ```  
   to **Framework Search Paths**.  

3. For **Bluetooth printers**, update your `Info.plist` file:  
   - Add **Supported external accessory protocols** (`UISupportedExternalAccessoryProtocols`).  
   - Set `Item 0` to:  
     ```sh  
     jp.star-m.starpro  
     ```  

---

## Usage  

```javascript  
import { StarPRNT } from 'rn-star-prnt';

async function portDiscovery() {  
    try {  
        let printers = await StarPRNT.portDiscovery('All');  
        console.log(printers);  
    } catch (e) {  
        console.error(e);  
    }  
}  
```  

## Contributing  

I am **not actively maintaining** this package beyond ensuring it remains functional. However, **pull requests are welcome** if you want to improve it!  