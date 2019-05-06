const fs = require('fs');

const charset = fs.readFileSync("charset.rom").slice(8192);

fs.writeFileSync("charset.8k.rom", charset);


