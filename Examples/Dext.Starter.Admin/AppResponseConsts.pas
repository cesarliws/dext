unit AppResponseConsts;

interface

const
  // Customers
  HTML_CUSTOMER_ROW = 
    '<tr id="customer-row-%d">' +
    '  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">%d</td>' +
    '  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 font-medium">%s</td>' +
    '  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">%s</td>' +
    '  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">%s</td>' +
    '  <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">' +
    '    <div class="flex items-center justify-end space-x-2">' +
    '      <button hx-get="/customers/%d/form" hx-target="#modal-container" ' +
    '              class="text-indigo-600 hover:text-indigo-900" title="Edit">' +
    '        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">' +
    '          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' +
    '                d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>' +
    '        </svg>' +
    '      </button>' +
    '      <button hx-delete="/customers/%d" hx-confirm="Delete this customer?" ' +
    '              hx-target="closest tr" hx-swap="outerHTML" ' +
    '              class="text-red-600 hover:text-red-900" title="Delete">' +
    '        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">' +
    '          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' +
    '                d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>' +
    '        </svg>' +
    '      </button>' +
    '    </div>' +
    '  </td>' +
    '</tr>';

  HTML_CUSTOMER_FORM = 
    '<div id="modal-backdrop" class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">' +
    '  <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">' +
    '    <div class="flex justify-between items-center mb-4">' +
    '      <h3 class="text-lg font-medium text-gray-900">%s</h3>' +
    '      <button onclick="document.getElementById(''modal-container'').innerHTML=''''" ' +
    '              class="text-gray-400 hover:text-gray-500">' +
    '        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">' +
    '          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>' +
    '        </svg>' +
    '      </button>' +
    '    </div>' +
    '    <form %s="%s" hx-target="%s" hx-swap="%s" hx-ext="json-enc" class="space-y-4">' +
    '      <div>' +
    '        <label for="name" class="block text-sm font-medium text-gray-700">Name</label>' +
    '        <input type="text" name="name" id="name" value="%s" required ' +
    '               class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500">' +
    '      </div>' +
    '      <div>' +
    '        <label for="email" class="block text-sm font-medium text-gray-700">Email</label>' +
    '        <input type="email" name="email" id="email" value="%s" required ' +
    '               class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500">' +
    '      </div>' +
    '      <div>' +
    '        <label for="TotalSpent" class="block text-sm font-medium text-gray-700">Total Spent</label>' +
    '        <input type="number" name="TotalSpent" id="TotalSpent" value="%s" step="0.01" ' +
    '               class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500">' +
    '      </div>' +
    '      <div class="flex justify-end space-x-3 pt-4">' +
    '        <button type="button" onclick="document.getElementById(''modal-container'').innerHTML=''''" ' +
    '                class="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 hover:bg-gray-50">Cancel</button>' +
    '        <button type="submit" ' +
    '                class="px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700">Save</button>' +
    '      </div>' +
    '    </form>' +
    '  </div>' +
    '</div>';

  HTML_CUSTOMER_LIST_HEADER = 
    '<div class="bg-white rounded-lg shadow overflow-hidden">' +
    '  <div class="px-6 py-4 border-b border-gray-200 flex justify-between items-center">' +
    '    <h3 class="text-lg font-medium text-gray-900">Customers</h3>' +
    '    <button hx-get="/customers/form" hx-target="#modal-container" ' +
    '            class="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 flex items-center">' +
    '      <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">' +
    '        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>' +
    '      </svg>' +
    '      Add Customer' +
    '    </button>' +
    '  </div>' +
    '  <table class="min-w-full divide-y divide-gray-200">' +
    '    <thead class="bg-gray-50">' +
    '      <tr>' +
    '        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">ID</th>' +
    '        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>' +
    '        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>' +
    '        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Spent</th>' +
    '        <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>' +
    '      </tr>' +
    '    </thead>' +
    '    <tbody class="bg-white divide-y divide-gray-200" id="customers-table-body">';

  HTML_CUSTOMER_LIST_FOOTER = 
    '    </tbody>' +
    '  </table>' +
    '</div>';

  // Dashboard
  HTML_DASHBOARD_STATS = 
    '<div class="bg-white rounded-lg shadow p-6">' +
    '  <h3 class="text-sm font-medium text-gray-500">Total Customers</h3>' +
    '  <p class="text-2xl font-bold text-gray-900 mt-2">%d</p>' +
    '</div>' +
    '<div class="bg-white rounded-lg shadow p-6">' +
    '  <h3 class="text-sm font-medium text-gray-500">Total Revenue</h3>' +
    '  <p class="text-2xl font-bold text-gray-900 mt-2">%s</p>' +
    '</div>';
    
  JSON_DASHBOARD_CHART = '{' +
    '"labels": ["Jan", "Feb", "Mar", "Apr", "May", "Jun"],' +
    '"datasets": [{' +
      '"label": "Sales",' +
      '"data": [12, 19, 3, 5, 2, 3],' +
      '"borderWidth": 1' +
    '}]' +
  '}';

  // Settings
  HTML_NOTIFICATION_SUCCESS = 
    '<div class="bg-green-100 border-l-4 border-green-500 text-green-700 p-4 mb-4" role="alert">' +
    '  <p class="font-bold">Success</p>' +
    '  <p>%s</p>' +
    '</div>';
    
  HTML_NOTIFICATION_ERROR = 
    '<div class="bg-red-100 border-l-4 border-red-500 text-red-700 p-4 mb-4" role="alert">' +
    '  <p class="font-bold">Error</p>' +
    '  <p>%s</p>' +
    '</div>';

implementation

end.
