---
module: [kind=guide] ccget-adding-package
---

# Adding a package to CCGET

Packages can be added to CCGET easily by following these steps!

## Step 1 - `ccpackage.json`

To add a program to CCGET you need to make a `ccpackage.json` file alongside your code, for example:

```text
folder/
|_ main.lua
|_ ccpackage.json
```

Inside the `ccpackage.json` you may add the following contents:

```json
{
    "name": "<program name>",
    "description": "<description>",
    "version": "<version>",
    "author": "<your_username>",
    "license": {
        "spdx_id": "<a valid spdx license id>",
        "name": "<the license name>",
        "url": "<a viewable webpage to the license>",
        "raw_url": "<a raw text url to the license>"
    },
    "files": {
        "<a file name>": "<source url>"
        ...
    }
}
```

### Name

The name is the name for your program for example:

```json
{
    "name": "ccget"
    ...
}
```

### Version

The version is a version of your package. [Semantic Versioning](https://semver.org/) is recommended.

```json
{
    ...
    "version": "0.1.0"
    ...
}
```

### Description

The description describes what your program does, for example:

```json
{
    ...
    "description": "A package manager for computer craft!"
    ...
}
```

### Author

The author is yourself! For example:

```json
{
    ...
    "author": "ajh123"
    ...
}
```

But please **no spaces**!

### License

You should add a license so other people know what they can do with your code! Without one they may not be allowed to download the program. Without a license I (ajh123) will not know if your program can be distributed on CCGET. See <https://en.wikipedia.org/wiki/Software_license> for more details.

Example:

```json
{
    ...
    "license": {
        "spdx_id": "EPL-2.0",
        "name": "Eclipse Public License - v 2.0",
        "url": "https://github.com/ajh123/Programs-CC/blob/main/LICENSE",
        "raw_url": "https://github.com/ajh123/Programs-CC/raw/main/LICENSE"
    },
    ...
}
```

But what's a *`spdx_id`*? The `spdx_id` is a standard identifier to a license part of the SPDX Specification. To find the identifier for your license visit <https://spdx.org/licenses/>.

If there is no identifier for your license you should remove the `spdx_id` field.

### File sources

File sources contain a URL to the raw contents of a file in your program, for example:

```json
{
    ...
    "files": {
        "main.lua": "https://github.com/ajh123/Programs-CC/raw/main/programs/ccget/main.lua",
        "dir/two.lua": "https://example.com/main.lua",
        "prog/ccbrowser.lua": "https://pastebin.com/raw/964NZUAU"
    }
    ...
}
```

As you may see, each file inside your code must be added. For each file you must provide the destination and the url for where it comes from. You may use any services which provide raw file hosting,

For example, a Pastebin url: `https://pastebin.com/raw/964NZUAU`, or a GitHub url: `https://github.com/ajh123/Programs-CC/raw/main/programs/ccget/main.lua`.

> [!NOTE]
> I understand that adding files manually is time consuming and cumbersome. Currently, this is the way it has to be done.
>
> In the future there will be ways to simplify this.

## Step 2 - Submission

To submit your program you may create a [request](https://github.com/ajh123/Programs-CC/issues/new?assignees=&labels=ccget&projects=&template=ccget_submit.yml&title=%5BCCGET+-+Submission%5D%3A+) on my GitHub. Please complete the sections in the form.

Then you must wait for my approval. Good luck!
