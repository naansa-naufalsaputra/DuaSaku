const babel = require('@babel/core');
const path = require('path');

try {
  const config = babel.loadPartialConfig({
    filename: path.join(__dirname, '../index.js'),
    cwd: path.join(__dirname, '../'),
  });
  console.log('Babel Config Plugins:', JSON.stringify(config.options.plugins, null, 2));
} catch (error) {
  console.error('Error loading Babel config:', error);
}
