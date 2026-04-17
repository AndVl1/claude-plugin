# Compose UI Templates for Feature Slices

## ViewState Template

```kotlin
sealed class <Name>ViewState {
    data object Loading : <Name>ViewState()

    data class Success(
        val data: <DataType>       // or List<<ItemType>> for lists
    ) : <Name>ViewState()

    data class Error(
        val message: String,
        val retryable: Boolean = true
    ) : <Name>ViewState()

    // Include for list features only:
    data object Empty : <Name>ViewState()
}
```

## ViewEvent Template

```kotlin
sealed class <Name>Event {
    // Navigation
    data class ItemClicked(val id: String) : <Name>Event()
    data object BackPressed : <Name>Event()

    // Actions
    data object Retry : <Name>Event()
    data object Refresh : <Name>Event()

    // For list features:
    data object LoadMore : <Name>Event()

    // For form features:
    data class FieldChanged(val field: String, val value: String) : <Name>Event()
    data object Submit : <Name>Event()
}
```

## Screen Template (Thin Adapter)

```kotlin
@Composable
fun <Name>Screen(component: <Name>Component) {
    val viewState by component.viewState.subscribeAsState()
    <Name>View(
        viewState = viewState,
        eventHandler = component::obtainEvent
    )
}
```

## View Template — List Feature

```kotlin
@Composable
fun <Name>View(
    viewState: <Name>ViewState,
    eventHandler: (<Name>Event) -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(Res.string.<name>_title)) },
                navigationIcon = {
                    IconButton(onClick = { eventHandler(<Name>Event.BackPressed) }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                    }
                }
            )
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when (val state = viewState) {
                is <Name>ViewState.Loading -> LoadingContent()
                is <Name>ViewState.Empty -> EmptyContent(eventHandler)
                is <Name>ViewState.Error -> ErrorContent(state, eventHandler)
                is <Name>ViewState.Success -> SuccessContent(state.data, eventHandler)
            }
        }
    }
}

@Composable
private fun LoadingContent() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        CircularProgressIndicator()
    }
}

@Composable
private fun EmptyContent(eventHandler: (<Name>Event) -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = stringResource(Res.string.<name>_empty),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(Modifier.height(16.dp))
        TextButton(onClick = { eventHandler(<Name>Event.Refresh) }) {
            Text(stringResource(Res.string.refresh))
        }
    }
}

@Composable
private fun ErrorContent(
    state: <Name>ViewState.Error,
    eventHandler: (<Name>Event) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = state.message,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.error
        )
        if (state.retryable) {
            Spacer(Modifier.height(16.dp))
            Button(onClick = { eventHandler(<Name>Event.Retry) }) {
                Text(stringResource(Res.string.retry))
            }
        }
    }
}

@Composable
private fun SuccessContent(
    items: List<<ItemType>>,
    eventHandler: (<Name>Event) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(items, key = { it.id }) { item ->
            <Name>ItemCard(
                item = item,
                onClick = { eventHandler(<Name>Event.ItemClicked(item.id)) }
            )
        }
    }
}

@Composable
private fun <Name>ItemCard(
    item: <ItemType>,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = item.title,
                style = MaterialTheme.typography.titleMedium
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = item.subtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
```

## View Template — Detail Feature

```kotlin
@Composable
fun <Name>DetailView(
    viewState: <Name>DetailViewState,
    eventHandler: (<Name>DetailEvent) -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(Res.string.<name>_detail_title)) },
                navigationIcon = {
                    IconButton(onClick = { eventHandler(<Name>DetailEvent.BackPressed) }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                    }
                }
            )
        }
    ) { padding ->
        when (val state = viewState) {
            is <Name>DetailViewState.Loading -> {
                Box(
                    modifier = Modifier.fillMaxSize().padding(padding),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            }
            is <Name>DetailViewState.Error -> {
                ErrorContent(state.message, state.retryable, eventHandler, Modifier.padding(padding))
            }
            is <Name>DetailViewState.Success -> {
                <Name>DetailContent(state.data, eventHandler, Modifier.padding(padding))
            }
        }
    }
}

@Composable
private fun <Name>DetailContent(
    data: <DetailType>,
    eventHandler: (<Name>DetailEvent) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp)
    ) {
        // Header section
        Text(
            text = data.title,
            style = MaterialTheme.typography.headlineMedium
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = data.description,
            style = MaterialTheme.typography.bodyLarge
        )

        Spacer(Modifier.height(24.dp))

        // Detail sections
        // Add feature-specific content here
    }
}
```

## View Template — Form Feature

```kotlin
@Composable
fun <Name>FormView(
    viewState: <Name>FormViewState,
    eventHandler: (<Name>FormEvent) -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(Res.string.<name>_form_title)) },
                navigationIcon = {
                    IconButton(onClick = { eventHandler(<Name>FormEvent.BackPressed) }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp)
        ) {
            // Form fields
            OutlinedTextField(
                value = viewState.fieldValue,
                onValueChange = { eventHandler(<Name>FormEvent.FieldChanged("field", it)) },
                label = { Text(stringResource(Res.string.<name>_field_label)) },
                isError = viewState.fieldError != null,
                supportingText = viewState.fieldError?.let { { Text(it) } },
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(24.dp))

            // Submit button
            Button(
                onClick = { eventHandler(<Name>FormEvent.Submit) },
                enabled = !viewState.isSubmitting,
                modifier = Modifier.fillMaxWidth()
            ) {
                if (viewState.isSubmitting) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(16.dp),
                        strokeWidth = 2.dp
                    )
                } else {
                    Text(stringResource(Res.string.submit))
                }
            }
        }
    }
}
```

## Spacing and Layout Rules

| Spacing | Usage |
|---------|-------|
| `4.dp` | Tight: between label and supporting text |
| `8.dp` | Small: between related items in a list |
| `16.dp` | Standard: padding, between sections |
| `24.dp` | Large: between major sections |

**Maximum nesting depth**: 3 levels. Extract private composables for deeper UI trees.
