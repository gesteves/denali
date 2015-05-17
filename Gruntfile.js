'use strict';

module.exports = function(grunt) {

  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    jshint: {
      files: ['Gruntfile.js', 'app/assets/javascripts/admin/*.js', 'app/assets/javascripts/application/*.js'],
      options: {
        node: true,
        curly: true,
        eqeqeq: true,
        indent: 2,
        quotmark: 'single',
        unused: true,
        trailing: true,
        smarttabs: true,
        eqnull: true,
        browser: true,
        strict: true,
        globals: {
          jQuery: true,
          _: true,
          Modernizr: true,
          Dropbox: true,
          Awesomplete: true
        },
      }
    },
    scsslint: {
      allFiles: [
        'app/assets/stylesheets/**/*.scss',
      ],
      options: {
        exclude: 'app/assets/stylesheets/vendors/**/*',
        config: '.scss-lint.yml',
        bundleExec: true
      }
    },
    watch: {
      js: {
        files: '<%= jshint.files %>',
        tasks: 'jshint'
      },
      sass: {
        files: ['.scss-lint.yml', 'app/assets/stylesheets/**/*.scss'],
        tasks: 'scsslint'
      }
    }
  });

  grunt.loadNpmTasks('grunt-contrib-jshint');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-scss-lint');

  grunt.registerTask('default', 'watch');
};
