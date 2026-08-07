import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';
const js = fs.readFileSync('wallpapers.js','utf8');
const OUT = process.argv[2] || '../../packages/sysible-artwork/backgrounds';
fs.mkdirSync(OUT, {recursive:true});
const W=3840, H=2160;
const b = await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
const p = await b.newPage();
await p.setContent('<!doctype html><html><head><meta charset="utf-8"></head><body></body></html>');
await p.addScriptTag({content: js});
const keys = await p.evaluate(()=>window.SYS.keys);
for (const key of keys){
  const dataUrl = await p.evaluate(({key,W,H})=>{
    const c=document.createElement('canvas'); c.width=W; c.height=H;
    window.SYS.render(key,c.getContext('2d'),W,H);
    return c.toDataURL('image/png');
  }, {key,W,H});
  const buf = Buffer.from(dataUrl.split(',')[1],'base64');
  const f = path.join(OUT, 'sysible-'+key+'.png');
  fs.writeFileSync(f, buf);
  console.log('wrote', f, (buf.length/1024/1024).toFixed(2)+'MB');
}
await b.close();
