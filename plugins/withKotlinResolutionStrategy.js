const { withProjectBuildGradle } = require('@expo/config-plugins');

module.exports = function withKotlinResolutionStrategy(config) {
  return withProjectBuildGradle(config, (config) => {
    if (config.modResults.language === 'groovy') {
      let buildGradle = config.modResults.contents;

      // Add resolutionStrategy inside allprojects
      const resolutionStrategyStr = `
    configurations.all {
        resolutionStrategy.eachDependency { details ->
            if (details.requested.group == "org.jetbrains.kotlin") {
                details.useVersion("1.7.20")
            }
        }
    }
`;

      if (!buildGradle.includes('resolutionStrategy.eachDependency')) {
        buildGradle = buildGradle.replace(
          /allprojects\s*\{/,
          `allprojects {${resolutionStrategyStr}`
        );
      }

      // Strictly hardcode the kotlin-gradle-plugin version just in case
      buildGradle = buildGradle.replace(
        'classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")',
        'classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.7.20")'
      );

      config.modResults.contents = buildGradle;
    }
    return config;
  });
};
