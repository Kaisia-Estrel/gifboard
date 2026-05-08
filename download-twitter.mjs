#!/usr/bin/env node

import { mkdtemp } from 'node:fs/promises';
import { Readable } from "stream";
import fs from 'fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { spawn } from "node:child_process";

async function downloadGif(identifier) {
  const video_url = `https://video.twimg.com/tweet_video/${identifier}.mp4`;
  console.log(`Video found: ${video_url}`);

  const fileloc = join( await mkdtemp(join(tmpdir(), 'download-twitter-')), identifier);
  const vid_res = Readable.fromWeb(
    (await fetch(video_url, {
      headers: {
      "User-Agent": "curl/8.0.0",
      "Accept": "*/*"
      }
    })).body
  );
  const vid_ws = await fs.createWriteStream(`${fileloc}.mp4`);
  await new Promise((resolve, reject) => {
      vid_res.pipe(vid_ws);
      vid_res.on("error", reject);
      vid_ws.on("finish", resolve);
  })

  const runWl = () => {
    const wl = spawn("wl-copy", ["--type", "text/uri-list", `file://${fileloc}.gif`], {
      stdio: ["ignore", "ignore", "ignore"]
    });

    wl.on('close', (code) => {
      console.log("Copied to clipboard");
    })
  }

  console.log(`tmpfile '${fileloc}.mp4' downloaded, converting to gif`);
  const ffmpeg = spawn("ffmpeg", ["-loglevel", "error", "-i", `${fileloc}.mp4`, `${fileloc}.gif`]);

  ffmpeg.stderr.on("data", (data) => {
    process.stderr.write(`[ffmpeg] ${data}`);
  });

  ffmpeg.on('close', (code) => {
    if (code !== 0) {
      console.error("Error converting mp4 to gif")
      return;
    }
    console.log(`File converted: saved to '${fileloc}.gif'`);
    runWl();
  });
}

const url = process.argv[2];
const res = await fetch(url, {
    headers: {
    "User-Agent": "curl/8.0.0",
    "Accept": "*/*"
    }
})
const content = await res.text();

const gif_rgx = /tweet_video\/(.*?)\.mp4/;
const mp4_rgx = /"(https:\/\/video.twimg.com\/amplify_video\/\d+\/vid\/avc1\/(\d+)x(\d+)\/([^}]*?).mp4)/g;

const gif_matches = content.match(gif_rgx);
const mp4_matches = [...content.matchAll(mp4_rgx)];

if (gif_matches !== null) {
    console.log("Found gif");
    downloadGif(gif_matches[1]);
} else if (mp4_matches.length !== 0) {
    console.log("Found mp4");
    let resolutions = new Map();
    for (const match of mp4_matches) {
      const url = match[1];
      const width = Number(match[2]);
      const height = Number(match[3]);
      const identifier = match[4];
      resolutions.set(width * height, [width, height, url, identifier]);
    }

    console.log("Found mp4 resolutions: ");
    let i = 0;
    for (const [width, height, url, _] of resolutions.values()) {
      console.log(`[${i}] (${width}x${height}): ${url}`);
      i++;
    }
    console.log("Downloading highest resolution");
    const [width, height, url, identifier] = resolutions.get(Math.max(...resolutions.keys()));
    const fileloc = join( await mkdtemp(join(tmpdir(), 'download-twitter-')), `${identifier}-${width}x${height}`);
    const mp4_res = Readable.fromWeb(
      (await fetch(url, {
        headers: {
        "User-Agent": "curl/8.0.0",
        "Accept": "*/*"
        }
      })).body
    );
    const mp4_ws = await fs.createWriteStream(`${fileloc}.mp4`);
    await new Promise((resolve, reject) => {
        mp4_res.pipe(mp4_ws);
        mp4_res.on("error", reject);
        mp4_ws.on("finish", resolve);
    })
    console.log(`File downloaded: saved to '${fileloc}.mp4'`);
    const wl = spawn("wl-copy", ["--type", "text/uri-list", `file://${fileloc}.mp4`], {
      stdio: ["ignore", "ignore", "ignore"]
    });

    wl.on('close', (code) => {
      console.log("Copied to clipboard");
    })

} else {
  console.error("Could not find gif or mp4");
}
