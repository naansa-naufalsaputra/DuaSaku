module.exports = function (api) {
  api.cache(false);
  return {
    presets: [
      ["babel-preset-expo", { jsxImportSource: "nativewind" }],
      "nativewind/babel"
    ],
    plugins: [
      ["module-resolver", {
        alias: {
          "react-native-worklets": "react-native-worklets-core"
        }
      }],
      "react-native-worklets-core/plugin",
      "react-native-reanimated/plugin" // This MUST be the last plugin
    ],
  };
};