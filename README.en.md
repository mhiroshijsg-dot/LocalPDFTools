# LocalPDFTools

A Mac app that **merges, splits, rotates, unlocks, compresses, and extracts text from** PDFs **entirely on your Mac**.
Your files are never uploaded to the internet, so you can safely work with important documents such as transcripts and ID cards.

*日本語: [README.md](README.md)*

---

## What it does

Add PDFs to the window, turn on the actions you want, and click “Run and Save…”. Several actions can run one after another (for example: Unlock → Rotate → Merge → Compress).

| Action | What it does |
|---|---|
| **Unlock** | Removes restrictions from PDFs that open but prohibit printing or copying. PDFs that need a password to open can be unlocked too, if you enter the password |
| **Rotate** | Click page thumbnails to turn pages 90° at a time. You can also rotate all pages at once |
| **Merge** | Combines several PDFs into one. Drag to change the order |
| **Split** | Splits one PDF into several PDFs: one page each, every N pages, by page ranges you enter, or at cut points you choose while viewing the pages. The split PDFs are saved together in a new folder |
| **Compress** | Makes files smaller. Just pick a quality (High, Medium, Low). Compression that doesn’t change the appearance is always done, and you can also lower image resolution or JPEG quality, rasterize heavy charts, and more. You can check how small the file will get before saving |
| **Extract Text** | Gets the text out of PDFs so you can copy it or save it as .txt. Scanned PDFs are read with the Mac’s built-in text recognition (OCR) |

Unlock, Rotate, Merge, and Split work without rebuilding the pages, so text, image quality, and file size stay almost the same.

For detailed instructions, open the app’s **Help** menu → **LocalPDFTools Help** (⌘?). You can search the help with the field at the top left of the Help window.

The interface is available in Japanese and English (see [Display language](#display-language)).

## Requirements

- **A Mac with Apple silicon (M1 or later)**. It does not run on Intel Macs
- **macOS 14 Sonoma or later**

## Installation

1. Download `LocalPDFTools-<version>.zip` from the [Releases page](https://github.com/mhiroshijsg-dot/LocalPDFTools/releases/latest).
2. Double-click the downloaded zip to expand it.
3. Move `LocalPDFTools` to your Applications folder.

### One-time step on first launch

This app is made by an individual and is not notarized by Apple. The first time you open it, macOS stops with a message such as
“‘LocalPDFTools’ Not Opened” / “Apple could not verify ‘LocalPDFTools’ is free of malware that may harm your Mac or compromise your privacy.”
Open it like this:

1. Click **Done** to close the message (don’t click **Move to Trash**).
2. Open **System Settings** → **Privacy & Security**.
3. In the **Security** section near the bottom, you’ll see that “LocalPDFTools” was blocked. Click **Open Anyway**.
4. Enter your password (or use Touch ID) if asked. Click **Open Anyway** again in the confirmation, and the app starts.

From then on, it opens normally.

## How to use

The window has three parts.

- **Left, “Files”**: Drag and drop PDFs onto the window, or click “+” (⌘O) at the top right. Files are listed top to bottom; drag rows to reorder them. Encrypted PDFs get a “Restricted” or “Password required” badge.
- **Right, “Actions”**: Turn on the actions you want. Actions that are on run from top to bottom.
- **Bottom**: Arrows show what will happen (for example: Unlock → Rotate → Merge → Save as one PDF). Check the file name and destination, then click **Run and Save…** (⌘S).

You are asked where to save and what name to use every time. **Original files are never overwritten** (if you choose the original file as the destination, the app stops).

- **With Merge on**, the result is saved as one PDF.
- **With Merge off**, each file is saved separately, with a save dialog for each one (the default name is the original name plus `_unlocked`, `_rotated`, and so on).
- **With Split on**, you choose a location just once. The app creates a new folder there and puts all the split PDFs in it.

### Order of operations
- You can change the order of Rotate, Merge, Split, and Compress in **Settings (⌘,)** by dragging rows. The default is Rotate → Merge → Split → Compress.
- Unlock always comes first.

### Unlock
- When it’s on, the app shows how many PDFs are restricted and how many need a password. Hover over a badge to see what is prohibited.
- Before removing protection, the app asks you to confirm with “Remove protection and continue”.
- For PDFs that need a password, you are asked for it when that PDF’s turn comes during the run. The password is used only for processing on this Mac. It is never saved or sent anywhere.
- Before saving, the app checks that the PDF is really no longer encrypted.
- If you only rotate or compress (no Unlock or Merge), the restrictions are kept (they are never removed silently).
- **Use this only on documents you have the rights to.** Don’t use it on other people’s documents or on documents whose restrictions you’re not allowed to remove.

### Rotate
- Click “View and rotate pages…” to see all pages of the PDFs you added.
- Each click turns a page 90° to the right. Right-click to choose left, 180°, or reset.
- Use “Rotate all left 90°” and “Rotate all right 90°” at the top to rotate every page. “Reset all” returns everything to the original orientation.
- PDFs that need a password to open can’t show their pages, so they can’t be rotated.

### Merge
- PDFs are combined in the order they appear in the list on the left.
- **Bookmarks (table of contents) and links within the document are lost when merging**. Web links are kept. The app lets you know when a PDF has bookmarks.
- Merge can’t be used together with Split (only one of them can be on).

### Split
- There are four ways to split:
  - **One page each**: A 10-page PDF becomes 10 PDFs.
  - **Every N pages**: With 3, the pages are split as 1–3, 4–6, and so on. The last PDF gets the remaining pages.
  - **Enter ranges**: Write ranges like `1-3, 4-7, 8-`. Each range becomes one PDF, in the order you write them (`8-` means page 8 to the end). Write just one range to take out only some of the pages.
  - **Choose cut points**: Click “View and split pages…” to see page thumbnails, then click between pages to cut there.
- Enter ranges and Choose cut points work only with one PDF. With several PDFs, each one is split the same way.
- When you save, the app creates a new folder (by default `original name_split`) in the location you choose and saves the pieces with names like `original name_p1-3.pdf`. If a folder with the same name already exists, it creates a new one with a number added, such as “name 2”.
- After saving, the app shows the number of files, the total size, the size of the largest file, and the list of files.
- Text, image quality, and web links don’t change. **Bookmarks (table of contents), links to pages within the PDF, and restrictions on editing, printing, and so on are not kept** (the app asks you to confirm before splitting a restricted PDF).
- Fonts, and images used on many pages, are included in each split PDF, so the total can be larger than the original. Size limits of the site you upload to apply to each file, so check “Largest file”. If Compress is also on, each split PDF is compressed.

### Compress
- Usually you just pick a **quality**: High, Medium, or Low (High is the default).
  - **High**: Shrinks only images finer than 300 dpi. The appearance hardly changes.
  - **Medium**: Shrinks images to 150 dpi and re-saves JPEGs at “Medium” quality. Good enough for reading on screen.
  - **Low**: Shrinks images to 100 dpi and re-saves JPEGs at “Low” quality. You can see the images are rougher when zoomed in.
- Click **Details** to choose the methods yourself:
  - **Structural compression** (on by default): Packs the PDF’s internal objects together and recompresses them. The appearance doesn’t change at all.
  - **Resolution**: Shrinks only images finer than the chosen dpi (300, 200, 150, 100, 72). Coarser images are left alone.
  - **JPEG quality**: Re-saves JPEG images such as photos and color scans at the chosen quality.
  - **Thin out figure lines** (for charts made with tools like matplotlib): Removes minor grid lines and minor ticks, and simplifies curves. Both are selected by default, and the app shows how many lines can be removed. Removing lines changes the appearance.
  - **Rasterize figures** (off by default): Replaces charts with a huge number of points or lines (such as scatter plots with tens of thousands of points) with images of the same position and size. Use “Choose figures…” to pick them one by one. Text inside those figures can no longer be selected or searched (body text stays as it is).
- These four are **always done** without being chosen (the appearance doesn’t change, or barely changes):
  - Discard unneeded data (editing data that apps like Illustrator store, small page thumbnails, and so on)
  - Merge duplicates: images, fonts, and so on whose contents are exactly the same are kept only once (works well on merged PDFs)
  - Rebuild Type1 fonts, found in PDFs made with LaTeX and similar tools, in a smaller format (CFF) with the same shapes
  - Re-save images that are stored in color but contain only white, black, and gray as grayscale images
- After you add a PDF, the app shows an **estimate** of the compressed size (the size breakdown is under “Details”). The estimate is approximate; click **Run trial** for exact numbers (the app actually compresses the files, measures them, and deletes the test files right away).
- Enter the size limit (MB) of the site you upload to in **Target**, and the app shows green if the files are likely to fit and red if they are likely to exceed it.
- After compressing, the app shows what it did (how many images were shrunk, and so on). If a file got larger than the original, it tells you.
- PDFs that need a password can’t be looked inside until they are unlocked, so they are left out of the breakdown, estimate, and trial (they are still compressed).

### Extract Text
- Turn it on and click “View text…” to see the text of the PDFs page by page. Copy it from there, or save it as .txt (either all in one .txt or one file per PDF).
- For PDFs made on a computer, the text stored inside is taken out as is. There are no misreadings.
- Pages without text data, such as in scanned PDFs, are read with the Mac’s built-in text recognition (OCR) when you click “Run OCR” on the page. Japanese and English are recognized.
- OCR can misread text (Roman numerals, ○, digits, and so on). Compare with the original PDF before you use the text in anything you submit.
- The recognized text is not embedded into the PDF (the app doesn’t make searchable PDFs).

### File name length
- The length of the file name (including `.pdf`) is shown next to it. Enter the rule of the site you upload to (for example, 50 characters or fewer) in “Limit”, and it turns red when the name is too long.

### Display language
- The app is available in Japanese and English. By default it follows your Mac’s language setting (Macs set to other languages get English).
- In **Settings (⌘,)**, use “Language” to switch just this app to 日本語 or English. Quit and reopen the app for the change to take effect.

## Privacy

- This app never connects to the internet. PDFs and passwords are never sent anywhere.
- Processing uses only [qpdf](https://qpdf.sourceforge.io/), which is bundled in the app, and components built into macOS.

## Getting help

Please report problems or requests in [Issues](https://github.com/mhiroshijsg-dot/LocalPDFTools/issues).
You can copy any error message shown in the app with the button on its right.

---

## For developers

You need:

- Xcode 27 or later
- qpdf from Homebrew (`brew install qpdf`). It is bundled into the .app on every build

Open `LocalPDFTools.xcodeproj`, then press ⌘R to run or ⌘U to run the tests.
The code layout is described in [`Sources/README.md`](Sources/README.md) (in Japanese).

The English translations of the interface are in `Localizable.xcstrings` (String Catalogs). The keys are the Japanese strings themselves, so write interface text in Japanese as before and add the English to the catalog.
The tests check Japanese interface text, so the scheme runs them in Japanese (`-AppleLanguages (ja)`).

To build the zip for distribution:

```
scripts/make_app.sh
```

This creates `build/LocalPDFTools.app` and `build/LocalPDFTools-<version>.zip`.
The version number comes from the Xcode project setting (MARKETING_VERSION).

## License

[MIT License](LICENSE)

qpdf, libjpeg-turbo, and OpenSSL, which are bundled in the .app, are under their own licenses.
Their license texts are in `Contents/Resources/ThirdPartyLicenses/` inside the .app.
