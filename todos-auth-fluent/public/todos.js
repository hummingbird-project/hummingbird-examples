const addTodoForm = document.getElementById("add-todo-form");
const logoutButton = document.getElementById("logout");
const doneCheckboxes = document.getElementsByClassName('done-checkbox')
const deleteButtons = document.getElementsByClassName('delete-button')

// add event listener for add todo submit
addTodoForm.addEventListener("submit", async (event) => {
    event.preventDefault();

    const title = document.getElementById("todo-title").value;
    await addTodo({"title": title});
    location.reload();
})

// add event listener for add todo submit
logoutButton.addEventListener("click", async (event) => {
    event.preventDefault();
    await logout();
    location.reload();
})

// add event listeners for each completed checkbox
Array.prototype.forEach.call(doneCheckboxes, checkbox => {
    checkbox.addEventListener("click", async (event) => {
        event.preventDefault();

        const srcElement = event.srcElement
        const id = srcElement.parentElement.parentElement.id
        const checked = srcElement.checked

        await setCompletedState(id, checked)
        location.reload();
    })
});

// add event listeners for each delete button
Array.prototype.forEach.call(deleteButtons, button => {
    button.addEventListener("click", async (event) => {
        event.preventDefault();

        const srcElement = event.srcElement
        const id = srcElement.parentElement.parentElement.id

        await deleteTodo(id)
        location.reload();
    })
});

/**
 * Logout user
 */
async function logout() {
    // Add Todo
    await fetch('/api/users/logout', {
        method: 'POST',
        headers: {"content-type": "application/json"}
    });
}

/**
 * Add new todo
 * @param {todo} todo Todo to add
 */
async function addTodo(todo) {
    // Add Todo
    await fetch('/api/todos', {
        method: 'POST',
        headers: {"content-type": "application/json"},
        body: JSON.stringify(todo)
    });
}

/**
 * Set Todo completion state
 * @param {string} id Todo id
 * @param {boolean} completed completed state to set
 */
async function setCompletedState(id, completed) {
    const editTodo = {"completed": completed};
    await fetch(`/api/todos/${id}`, {
        method: 'PATCH',
        headers: {"content-type": "application/json"},
        body: JSON.stringify(editTodo)
    });
}

/**
 * Delete todo
 * @param {string} id Todo id
 */
async function deleteTodo(id) {
    await fetch(`/api/todos/${id}`, {
        method: 'DELETE',
        headers: {"content-type": "application/json"}
    });
}