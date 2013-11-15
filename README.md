###Janus Notes

Janus Notes is a syncing note taking program for iOS and OSX that **seriously** respect your right to privacy.

It syncs encrypted notes through Dropbox services. It is named after the Latin God Janus, depicted as having two faces since he looks to the future and to the past. Or, may be, cloud storage and privacy. Or Macintoshes and iPhone/iPad. Or sharing and control. 

The built program is available for free from the [Mac App Store](http://itunes.apple.com/app/id651141191) and the iOS [App Store](http://itunes.apple.com/app/id651150600). End user description, [FAQ](http://www.janusnotes.com/faq.html) and [Screenshots](http://www.janusnotes.com/screenshots.html) are available at [janusnotes.com](http://www.janusnotes.com).

###The code

There are two Xcode 5 projects, one for iOS and the other for OS X, respectively on the IPhone and Mac subdirectory. Forks and contributions are always welcome. 

The code will generate the programs currently online on the stores, the only required thing not in the repository is the DropboxKeys.h header, containing the app key and the secred you'll need to access the Dropbox Sync API. The header file contains only 2 useful rows
	#define DROPBOX_APP_KEY @"xxxxxxxxxxxxxxx"
	#define DROPBOX_SECRET  @"xxxxxxxxxxxxxxx"

The program uses many OSS libraries:

[iRate](https://github.com/nicklockwood/iRate) Copyright 2011 Charcoal Design

[RNCryptor](https://github.com/rnapier/RNCryptor) Copyright (c) 2012 Rob Napier

[sundown](https://github.com/vmg/sundown) Copyright (c) 2009, Natacha Porté and Copyright (c) 2011, Vicent Marti

[MBProgressHUD](https://github.com/jdg/MBProgressHUD) Copyright (c) 2013 Matej Bukovinski

[AHAlertView](https://github.com/warrenm/AHAlertView) Copyright (C) 2012 Auerhaus Development, LLC

####License

The code is available under the (MIT license)[http://opensource.org/licenses/MIT].

Copyright (c) 2013 Giacomo Tufano

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.