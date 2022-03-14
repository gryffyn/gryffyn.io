---
title: "To All the Little Tools I've Written"
date: 2022-03-14T15:46:02+01:00
description: "Or, How I Spend My Weekends"
---

I have half a million little projects I've started, written a bit of code for, and then promptly forgotten about. Rather than focus on the projects I haven't done, I decided to take a bit of a look at the ones I have done. I was inspired to write this based on [this blog post](https://blog.carlmjohnson.net/post/2018/go-cli-tools/) by Carl M. Johnson that I saw on [lobste.rs](https://lobste.rs/s/nbhotp/more_than_dozen_command_line_tools_i_ve).

## strangelove
- **Description** // [strangelove](https://git.neveris.one/gryffyn/strangelove) is a bit of a WIP tool for inserting binary data into binary files, writing in-place at a specified offset.
- **Origin** // I wanted to make a tool that would scan a binary, find the largest continguous block of zero-value bytes, print those offsets, and then also have the ability to insert data at that (maybe automatically selected?) offset or a user-specified one.
- **Status** // WIP, this is one I'll definitely keep working on.
- **Usage** // It's a bit niche, but I wrote it for a larger project I'm working on, and I use it there frequently.
- **Satisfaction** // I completed the most important part of the program, which is the manual insertion of binary data. The hard stuff, I still haven't done. Overall, fairly satisfied.

## osiris
- **Description** // [osiris](https://git.neveris.one/gryffyn/osiris) renames video files based on a provided regex/named capture group specification.
- **Origin** // I had a whole lot of very unorganized files floating around which I needed to get into the same naming format.
- **Status** // Complete-ish
- **Usage** // Pretty frequent.
- **Satisfaction** // I'm pretty happy with this. I know it's a bit annoying to have to remember how the regex works, but I adore regex, and I haven't found this tool hard to remember.

## cbr2cbz
- **Description** // [cbr2cbz](https://git.neveris.one/gryffyn/cbr2cbz) converts RAR-compressed comic book archives into ZIP-compressed comic book archives. If it detects a file is already a ZIP but named as if it were a RAR (a surprisingly common occurence), it can simply rename it instead of un- and re-compressing the file.
- **Origin** // I had a lot of CBR files, and converting them to CBZ by hand was not very appealing. CBR files are not that widely supported due to RAR being a proprietary format.
- **Status** // Complete
- **Usage** // Not too frequent, but when I need it it's nice to have.
- **Satisfaction** // I'm quite happy with this tool. It does everything I need from it.

## pdf2cbz
- **Description** // [pdf2cbz](https://git.neveris.one/gryffyn/pdf2cbz) converts a PDF to a ZIP-compressed comic book archive (CBZ). It can crop the PDF pages before archiving them in the CBZ, drastically reducing file size on PDFs with a lot of blank space.
- **Origin** // As is apparently the case with every tool I have, I had a few PDFs I wanted in CBZ format, and doing it by hand was *really* not appealing.
- **Status** // WIP. JPEG export works, PNG export is a *litle* broken. See [here](https://git.neveris.one/gryffyn/pdf2cbz#a-word-s-of-warning) for details.
- **Usage** // Not very frequently, but it's a very nice tool to have.
- **Satisfaction** // I would be happier with this if I figured out the PNG issue. I haven't had much time to work on it, and JPEG is usually the correct choice anyways, so it may be a while before it's completed.
## exren
- **Description** // [exren](https://git.neveris.one/gryffyn/exren) takes in a format string and a file with EXIF data, and renames the file using the EXIF tags present in the image metadata and the format string
- **Origin** // One day we'll find a tool I haven't made because I had a bunch of files of the wrong name/format and I didn't want to convert them manually. But today is not that day.
- **Status** // Complete-ish
- **Usage** // I used this extensively to reformat my photo library, then I got busy and stopped taking pictures nearly as often, so unfortunately I haven't used this tool in a while.
- **Satisfaction** // I would like this tool if I found a better way to specify the EXIF tags. Right now it relies on a hardcoded list of tags, which isn't ideal as far as format support goes. It currently works on Nikon RAW, JPEG, and PNG files, as that's all I've tested it on.
