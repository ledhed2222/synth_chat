import base from '@ledhed2222/eslint-config'
import prettier from '@ledhed2222/eslint-config/prettier'
import globals from 'globals'

export default [
  { ignores: ['vendor/**'] },
  ...base,
  ...prettier,
  {
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: {
        ...globals.browser,
        process: 'readonly',
      },
    },
    rules: {
      'no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      // Phoenix LiveView hooks are conventionally single default exports.
      'import/no-default-export': 'off',
    },
  },
]
