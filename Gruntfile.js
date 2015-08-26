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
    svgstore: {
      options: {
        prefix: 'svg-',
        svg: {
          style: 'display: none;'
        },
        cleanup: ['style', 'fill', 'stroke']
      },
      default: {
        files: {
          'app/views/partials/_icons.svg.erb': ['tmp/app/assets/images/svg/*.svg']
        }
      }
    },
    svgmin: {
      options: {},
      dist: {
        files: [{
          expand: true,
          src: ['app/assets/images/svg/*.svg'],
          dest: 'tmp'
        }]
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
      },
      svg: {
        files: ['app/assets/svg/*.svg'],
        tasks: ['svgmin', 'svgstore']
      }
    }
  });

  grunt.loadNpmTasks('grunt-contrib-jshint');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-scss-lint');
  grunt.loadNpmTasks('grunt-svgstore');
  grunt.loadNpmTasks('grunt-svgmin');

  grunt.registerTask('default', 'watch');
  grunt.registerTask('svg', ['svgmin', 'svgstore']);
};
